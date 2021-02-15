#!/bin/bash

if (( $# < 3 ))
then
	echo 'USAGE: ./panopto-dl.sh cookie-file url-host folder-id'
	echo 'url-host should be, eg, uw.hosted.panopto.com'
	echo 'folder-id should be, eg, 1236-oneuh-r,churc,.hruc'
	exit 1
fi

if ! command -v jq >/dev/null
then
	echo 'You must install `jq`'
	exit 1
fi

cookie_file=$1
url_host=$2
folder_id=$3
user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36'

if ! [[ -r $cookie_file ]]
then
	echo "Cannot read cookie file $cookie_file"
	exit 1
fi

function ez_curl {
	curl -b "$cookie_file" -A "$user_agent" --connect-timeout 15 --retry 3 "$@"
}

echo 'Downloading folder...'
viewer_urls=$(ez_curl -XPOST -H 'Content-Type: application/json' \
	--data "{\"queryParameters\":{\"maxResults\":999,\"folderID\":\"$folder_id\"}}" \
	"https://$url_host/Panopto/Services/Data.svc/GetSessions" \
	| jq -r '.d.Results[] | .SessionName, .ViewerUrl')

echo "$(($(echo -n "$viewer_urls" | wc -l)/2)) videos found."
is_name=true
IFS='
'
for viewer_url in $viewer_urls
do
	if $is_name
	then
		is_name=false
		next_name=$viewer_url
	else
		is_name=true
		echo 'Downloading video details...'
		video_url=$(ez_curl "$viewer_url" | grep -oEm1 'https://.*?Podcast/Social/.*?mp4')
		echo "Downloading video: $next_name from $video_url..."
		ez_curl -Lo "$next_name.mp4" "$video_url"
	fi
done

