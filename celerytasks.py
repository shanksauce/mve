import config
import pickle
import celeryconfig
import logging
import time
from celery import Celery
from celery.task.sets import TaskSet

celery = Celery('celerytasks')
celery.config_from_object(celeryconfig)

config.configure_logging()

def extract_scrape_url(r, **kwargs):
	scrape_urls = []
	app_id = int(extract_single_value('.*?/id=([0-9]+)/.*$', r.url))
	if r.status_code != 200:
		logging.warning('Status was {0} for appID {1}'.format(r.status_code, app_id))
		return
	feed = parse_feed(r.json())
	page_url = [x for x in feed['link'] if x['attributes']['rel'] == 'last'][-1]['attributes']['href']
	num_pages = 1
	if len(page_url) > 0:
		num_pages = int(extract_single_value('.*?/page=([0-9]+)/.*$', page_url))
	for i in xrange(1, num_pages+1):
		scrape_urls.append(config.REVIEWS_URL.format(i, app_id))
	return scrape_urls

@celery.task(name='noop')
def noop():
    logging.info('NOOP')
    return 'NOOP'

#logging.info('Loading list of probe URLs from file')
#probe_urls = pickle.load(open('probe_urls.p', 'rb'))

pool_offset = 0
pool_size = 71

@celery.task(name='generate_scrape_urls')
def generate_scrape_urls():
	logging.info('Generating scrape URLS')
	global pool_offset
	global pool_size
	pool_max = pool_size+pool_offset
	scrape_urls = []
	while pool_offset < pool_max: #len(probe_urls):
		logging.info('{0}'.format(pool_offset))
		time.sleep(1)
#		logging.info('{0}%'.format(100*(pool_offset/len(probe_urls))))
#		rs = [grequests.get(probe_urls[i], callback=extract_scrape_url)]
#		grequests.map(rs, size=pool_size)
		pool_offset += 1
#	logging.info('Dumping scrape URLs to file'.format(len(scrape_urls)))
#	pickle.dump(scrape_urls, open('scrape_urls.p', 'wb'))
	return 'OK'

