#!/bin/bash
# INPUT
    # APP_ID 9 digit iTunes AppID string (required)
    # PAGELIMIT (optional)
    # PAGESTRT (optional)
# OUTPUT
    # | seperated list of comments for page
 
if [[ $1 ]]; then
    APP_ID=$1
    RSS_URL="http://itunes.apple.com/rss/customerreviews/id=${APP_ID}/json"
else
    echo 'ERROR: An AppID is required!'
    echo 'usage: $0 APPID [PAGELIMIT] [STARTPAGE]'
  exit 1
fi
 
# Check for optional page limit
if [[ $2 ]]; then
    PAGE_LIMIT=$2
fi
# Check for optional page start
if [[ $3 ]]; then
    PAGE_START=$3
else
    PAGE_START=1
fi
 
# Get the number of comment pages
PAGE_COUNT=`cat testfile.json | awk '
    match($0,/"attributes":{"rel":"last", "href":"[^"]+page=[0-9]+[^"]+"/) {
        gsub(/.+page=/,"",$0);
        gsub(/\/.+/,"",$0);
        print $0;
    }
'`
# Print file header
echo "review_id|app_version_id|author_id|review_author_name|rating_score|review_title|review_content";

# Get and parse comments for each page
PAGES_RUN=0
for ((i = $PAGE_START ; i <= ${PAGE_COUNT} ; i++ )); do
    PAGE_NUMBER=$i;
    RSS_URL="http://itunes.apple.com/us/rss/customerreviews/page=${PAGE_NUMBER}/id=${APP_ID}/sortby=mostrecent/json"
    echo $RSS_URL
    curl --silent $RSS_URL | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' |\
    awk 'BEGIN {FS="|";}  {
        if ($1 ~ /^ name/ && $2 ~ /^label/) {
            name=$3;
        }
        if ($1 ~ /^ im:version/ && $2 ~ /^label/) {
            version=$3;
        }
        if ($1 ~ /^ title/ && $2 ~ /^label/) {
            title=$3;
        }
        if ($1 ~ /^ content/ && $2 ~ /^label/) {
            content=$3;
            print commentid"|"version"|"authorid"|"name"|"rating"|"title"|"content;
        }
        if ($1 ~ /^ im:rating/ && $2 ~ /^label/) {
            rating=$3;
        }
        if ($1 ~ /^ id/ && $2 ~ /^label/) {
            commentid=$3;
        }
        if ($1 ~ /^author/ && $2 ~ /^uri/ && $3 ~ /^label/) {
            gsub(/https\:\/\/[^0-9]+/,"",$4); 
            authorid=$4;
        }
    }' | cat
 
    # Break if PAGELIMIT is reached
    PAGES_RUN=$((PAGES_RUN+1))
    if [[ $PAGE_LIMIT && $PAGES_RUN -ge $PAGE_LIMIT ]]; then
        break
    fi
done
exit
