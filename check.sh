#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/piriform-detect.git && cd piriform-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

if [ -f ~/uploader_credentials.txt ]; then
sed "s/folder = test/folder = `echo $appname`/" ../uploader.cfg > ../gd/$appname.cfg
else
echo google upload will not be used cause ~/uploader_credentials.txt do not exist
fi

productlist=$(cat <<EOF
Recuva
Speccy
Defraggler
CCleaner
extra line
EOF
)

printf %s "$productlist" | while IFS= read -r piriform
do {

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

lowercase=$(echo $piriform | tr '[:upper:]' '[:lower:]')
#set site vaiable
site=$(echo "https://www.piriform.com/$lowercase/download/standard")
#set change log url
changes=$(echo "https://www.piriform.com/$lowercase/version-history")
#some pattern to detect installer
searchpattern=$(echo "download.*piriform.*setup.*exe")

#download some information about site
wget -S --spider -o $tmp/output.log "$site"

#check if the site statuss is good
grep -A99 "^Resolving" $tmp/output.log | grep "HTTP.*200 OK"
if [ $? -eq 0 ]; then
#if file request retrieve http code 200 this means OK

#detect if the site still hosts some installer
wget -qO- "$site" | sed "s/http/\nhttp/g" | sed "s/exe/exe\n/g" | grep "^http.*exe$" | head -1 | grep "$searchpattern"
if [ $? -eq 0 ]; then

url=$(wget -qO- "$site" | sed "s/http/\nhttp/g" | sed "s/exe/exe\n/g" | grep "^http.*exe$" | head -1 | grep "$searchpattern")

#what filename is exact the latest
filename=$(wget -qO- "$site" | sed "s/http/\nhttp/g" | sed "s/exe/exe\n/g" | grep "^http.*exe$" | head -1 | sed "s/^.*\///g")

#check if this filename is in database
grep "$filename" $db > /dev/null
if [ $? -ne 0 ]; then
echo new version detected!

echo Downloading $filename
wget $url -O $tmp/$filename -q
echo

#check downloded file size if it is fair enought
size=$(du -b $tmp/$filename | sed "s/\s.*$//g")
if [ $size -gt 2048000 ]; then

echo extracting installer..
7z x $tmp/$filename -y -o$tmp > /dev/null
echo

#sometimes executable file name is in different case than real applicaition name. this is needed to be fixed
echo the following files wer found in installer:
exe32=$(find $tmp -maxdepth 1 -iname *`echo $piriform`.exe* | sed "s/^.*\///g")
echo $exe32
exe64=$(find $tmp -maxdepth 1 -iname *`echo $piriform`64.exe* | sed "s/^.*\///g")
echo $exe64
echo

echo detecting version.. this will take 2 minutes or something.
fullversionnumber=$(pestr $tmp/$exe32 | grep -A2 "^$piriform" | grep -A1 "^ProductVersion" | grep -v "ProductVersion")

versionpattern=$(echo "^[0-9]\+[\., ]\+[0-9]\+[\., ]\+[0-9]\+[\., ]\+[0-9]\+")
#detect exact verison
echo $fullversionnumber | grep "$versionpattern"
if [ $? -eq 0 ]; then
echo

#there are differences version number format between all four applications
#we are trying to find version number which is user worldwide
#at first it removes all spaces
#secondly it deletes everything after '-' symbol including '-'
#by default every applicaition has version z.y.z.w but we needed ony 3 so '.z' has removed
version=$(echo $fullversionnumber | sed "s/\s//g;s/-.*$//g;s/,/\./g;s/\.[0-9]\+//2")
echo $version
echo

echo looking for change log..
wget -qO- "$changes" | \
sed "s/<h6>/\n<h6>/g;s/<\/h6>/<\/h6>\n/g;s/<br\/>\|<br \/>//g" | \
grep -A99 "<h6>" | grep -m2 -B99 "<h6>" | grep "$version"
if [ $? -eq 0 ]; then
echo

changelog=$(wget -qO- "$changes" | sed "s/<h6>/\n<h6>/g;s/<\/h6>/<\/h6>\n/g;s/<br\/>\|<br \/>//g" | grep -A99 "$version" | grep -m2 -B99 "<h6>" | sed '/^\s*$/d' | grep -v "<h6>")

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
sha1x86=$(sha1sum $tmp/$exe32 | sed "s/\s.*//g")
sha1x64=$(sha1sum $tmp/$exe64 | sed "s/\s.*//g")
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
md5x86=$(md5sum $tmp/$exe32 | sed "s/\s.*//g")
md5x64=$(md5sum $tmp/$exe64 | sed "s/\s.*//g")

7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on $tmp/`echo $piriform`.exe.$version.7z $tmp/$exe32
7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on $tmp/`echo $piriform`64.exe.$version.7z $tmp/$exe64

echo "$filename">> $db
echo "$version">> $db
echo "$md5">> $db
echo "$sha1">> $db
echo >> $db

#if google drive config exists then upload and delete file:
if [ -f "../gd/$appname.cfg" ]
then
echo Uploading $filename to Google Drive..
echo Make sure you have created \"$appname\" directory inside it!
../uploader.py "../gd/$appname.cfg" "$tmp/$filename"
../uploader.py "../gd/$appname.cfg" "$tmp/`echo $piriform`.exe.$version.7z"
../uploader.py "../gd/$appname.cfg" "$tmp/`echo $piriform`64.exe.$version.7z"
echo
fi

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$piriform $version" "$url 
$md5
$sha1

https://2292fc14cff26c76cdd11414679cfe77df9b2f57.googledrive.com/host/0B_3uBwg3RcdVa0ptM2E5UEZUVlE/`echo $piriform`.exe.$version.7z 
$md5x86
$sha1x86

https://2292fc14cff26c76cdd11414679cfe77df9b2f57.googledrive.com/host/0B_3uBwg3RcdVa0ptM2E5UEZUVlE/`echo $piriform`64.exe.$version.7z 
$md5x64
$sha1x64

$changelog"
} done
echo

else
#change log not found
echo change log not found
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "$piriform change log not found: 
$changes "
} done
fi

else
#version number do not match the standart pattern
echo version number do not match the standart pattern
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "$piriform version number do not match the standart pattern: 
$url 
$versionpattern"
} done
fi

else
#downloaded file size is to small
echo downloaded file size is to small
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "Downloaded file size is to small: 
$site 
$filename 
$size"
} done
fi

else
#filename is already in database
echo filename is already in database
echo
fi

else
#there are no longer file on site
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "The following search pattern do not work anymore: 
$searchpattern 
$site "
} done
echo 
echo
fi

else
#site do not retrieve good status
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "The following site do not retrieve good http status code: 
$site "
} done
echo 
echo
fi

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null

} done
