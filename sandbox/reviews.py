#!/usr/bin/env python
import re
import os
import sys
import logging
import requests
from pprint import pprint

os.system('clear')
logging.basicConfig(format='[ %(levelname)s ] @ %(lineno)d: %(message)s', level=logging.INFO)

RSS_URL = 'http://itunes.apple.com/rss/customerreviews/id={0}/json'
REVIEWS_URL = 'http://itunes.apple.com/us/rss/customerreviews/page={0}/id={1}/sortby=mostrecent/json'

if len(sys.argv) != 2:
	print 'Please enter exactly one app ID\n'
	exit()

app_id = sys.argv[1]

try:
	logging.info('Probing app ID {0}...'.format(app_id))
	r = requests.get(REVIEWS_URL.format(1, app_id), headers={'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.95 Safari/537.36'})
	feed = r.json()
	if 'feed' not in feed:
		raise Exception('The feed seems to be messed up. Here\'s the raw JSON:\n%s ' % r.text)
	feed = feed['feed']
	page_url = [x for x in feed['link'] if x['attributes']['rel'] == 'last'][-1]['attributes']['href']
	match = re.match('.*?/page=([0-9]+)/.*$', page_url)
	if match is None:
		raise Exception('rel == last URL was empty')
	num_pages = int(match.group(1))
except Exception as ex:
	logging.error(ex.message)

