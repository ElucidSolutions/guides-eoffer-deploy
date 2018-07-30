#!/bin/bash
# This script accepts one argument: path, a
# file path refering to a eOffer Guides
# source directory; packages the source directory;
# posts the package to an AWS S3 bucket; and sends
# a notification email to GSA.

while getopts ":hv" option
do
  case $option in
    h) cat <<- EOF
Usage: deploy_guides_eoffer.sh [options] <path>

Accepts one argument: <path>, a URL path that references the
eOffer Guides project source directory; packages the source
directory; posts the package to an AWS S3 bucket; and sends a
notification email to GSA.

Example
> deploy_guides_eoffer.sh \
    /home/ubuntu/guides-eoffer

Dependencies

1. Mutt
   This utility relies on the venerable Mutt mail client
   (https://en.wikipedia.org/wiki/Mutt_(email_client)) to send
   emails.
2. AWS
   This utility relies on the AWS CLI utility to post content to
   remote AWS S3 buckets.

Author
Larry Lee <larry_lee@elucidsolutions.com>
EOF
      exit 0;;
    v) verbose=1 ;;
  esac
done
shift $((OPTIND - 1))

bucket="s3://amsystemssupport.fas.gsa.gov"
timestamp=$(date +%m%d%y)
source="guides-eoffer-$timestamp"
package="$source.zip"
hash="$package.sha1"

# Accepts one argument: emsg, an error message
# string; and prints the given error message.
function error () {
  local emsg=$1
  (>&2 echo -e "\033[41mError:\033[0m $emsg")
  exit 1
}

if [[ $# < 1 ]]
then
  error "\033[41mError:\033[0m Invalid command line. The <path> argument is missing."
else
  path=$1
fi

# Accepts one argument: message, a message
# string; and prints the given message iff the
# verbose flag has been set.
function display () {
  local message=$1

  if [[ $verbose == 1 ]]
  then
    echo -e "\033[44mNotice:\033[0m $message"
  fi
}

# I. Create the source directory.

display "Creating the source directory..."
cp -r $path $source || error "an error occured while trying to create the source directory."
rm -r $source/{.git,.sass-cache}
rm $source/{.gitattributes,.gitignore,config.rb}
display "Created the source directory."

# II. Package the source directory.

display "Creating the deployment package..."
zip -rq $package $source || error "an error occured while trying to package the source directory."
sha1sum $package > $hash
display "Created the deployment package."

# III. Post the package to AWS.

display "Posting the deployment package to AWS..."
aws s3 cp $package $bucket --acl public-read-write || error "an error occured while trying to upload the package to AWS."
aws s3 cp $hash $bucket --acl public-read-write || error "an error occured while trying to upload the hash file to AWS."
display "Posted the deployment package to AWS."

# IV. Send notification email.

recipient="etoolshelpdesk@gsa.gov"
cc="-c Robert.Sherwood@nolijconsulting.com -c thomas.ahn@gsa.gov -c larry.lee@nolijconsulting.com"

display "Notifying GSA..."
#mutt -s "Please deploy the eOffer User Guides Package" $cc $recipient <<- EOF
Hi,

The latest version of the eOffer User Guides (https://eoffer.gsa.gov/AMSupport/) is ready for deployment.

The source code package for this project can be downloaded from:

* https://s3.amazonaws.com/amsystemssupport.fas.gsa.gov/$package
* https://s3.amazonaws.com/amsystemssupport.fas.gsa.gov/$hash

The source code package for this site consist entirely of HTML, JS, CSS, and XML files. To deploy this package, simply replace the existing source files with those included in the package.

Please let me know once this update has been installed.

Thanks,
-- 
Larry Lee
EOF
display "Notification email sent."

# V. Clean up.

display "Cleaning up..."
rm -rf $package $source $hash
display "Done."
