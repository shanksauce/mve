import config
import celeryconfig
import logging
from celery import Celery
from celery.task.sets import TaskSet

celery = Celery('celerytasks')
celery.config_from_object(celeryconfig)

config.configure_logging()

@celery.task(name='noop')
def noop():
    logging.info('NOOP')
    return 'NOOP'
