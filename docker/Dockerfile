FROM public.ecr.aws/lambda/python:3.10.2024.06.10.10

COPY requirements.txt ${LAMBDA_TASK_ROOT}

RUN pip install -r requirements.txt

COPY get_iss_position.py ${LAMBDA_TASK_ROOT}

CMD [ "get_iss_position.lambda_handler" ]

