from celery.schedules import crontab
import config

CELERYD_CONCURRENCY = 8
CELERY_TIMEZONE = 'UTC'
CELERY_ENABLE_UTC = True
CELERY_TASK_SERIALIZER = 'json'
CELERY_TASK_RESULT_EXPIRES = 4*60
CELERY_RESULT_SERIALIZER = 'json'
CELERY_DISABLE_RATE_LIMITS = True
BROKER_POOL_LIMIT = int(CELERYD_CONCURRENCY/2)

BROKER_URL = 'redis://'+config.REDIS_HOSTNAME+':'+str(config.REDIS_PORT)+'/'
CELERY_RESULT_BACKEND = BROKER_URL+'/0'

CELERYBEAT_SCHEDULE = {
	'push_scrape_tasks': {
		'task': 'push_scrape_tasks',
		'schedule': crontab(minute='*/30')
	}
}
