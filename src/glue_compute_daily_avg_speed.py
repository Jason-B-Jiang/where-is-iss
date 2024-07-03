from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.window import Window
from pyspark.sql.types import DoubleType

from awsglue.context import GlueContext

from datetime import date, timedelta
import math

# Initialize GlueContext and SparkSession
sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

# Load in yesterday's location data from S3
yesterday = date.today() + timedelta(days=-1)
location_df = spark.read.parquet(f"s3://iss-location/{yesterday.strftime("%Y-%m-%d")}")

# Create UDF to compute Haversine distance between lat / long coordinates
def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate distance in km between two GPS coordinates (lat, long),
    as represented by (lat1, lon1) and (lat2, lon2).
    """
    if lat1 is None or lon1 is None or lat2 is None or lon2 is None:
        return
    
    lon1, lat1, lon2, lat2 = map(math.radians, [lon1, lat1, lon2, lat2])

    d_lon = lon2 - lon1
    d_lat = lat2 - lat1

    a = math.sin(d_lat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(d_lon / 2) ** 2
    c = 2 * math.asin(math.sqrt(a))

    return 6371 * c

haversine_udf = F.udf(haversine, DoubleType())

# Compute average hourly speed travelled yesterday
# Use Haversince function to compute distance between each hour, and take avg
w = Window.orderBy("latitude", "longitude", "timestamp_utc")

avg_speed = location_df \
    .withColumn("prev_latitude", F.lag("latitude").over(w)) \
    .withColumn("prev_longitude", F.lag("longitude").over(w)) \
    .withColumn("distance_km", haversine_udf(F.col("latitude"),
                                             F.col("longitude"),
                                             F.col("prev_latitude"),
                                             F.col("prev_longitude"))) \
    .agg(F.avg(F.col("distance_km")).alias("avg_speed")) \
    .withColumn("datestamp",
                F.to_date(F.lit(yesterday.strftime("%Y-%m-%d"), "YYYY-MM-dd")))

# Write average speed dataframe as parquet to separate S3 bucket
avg_speed.coalesce(1).write.mode("overwrite") \
    .parquet("s3://iss-daily-avg-speed/data/{yesterday.strftime("%Y-%m-%d")}")
