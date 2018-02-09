#! /bin/sh -
# display2.sh - Wifi Radio LCD display routines, revision 2
# 01/29/08      Jeff Keyzer     http://mightyohm.com
# This shell script queries mpd for current song information and sends
# relevant bits of it to the serial port, where an AVR-based LCD display
# is waiting.
#
# For more information, visit
# http://mightyohm.com/blog/tag/wifiradio/
#
# This work is protected by the
# Creative Commons Attribution-Share Alike 3.0 United States License.
# http://creativecommons.org/licenses/by-sa/3.0/us/
#

trap 'exit 1' SIGINT    # exit on ctrl-c, useful for debugging

#stty 9600 -echo < /dev/tts/0   # set serial port to 9600 baud
                                # so we can talk to the AVR

while true              # loop forever
do
   # get name of current song from the mpd server
   name=$(echo "currentsong" | nc localhost 6600 | grep -e "^Name: ")
   #echo $name
   echo $name > /dev/tts/0      # send it to the AVR for display

   # get the artist/title of the current song, if it exists
   title=$(echo "currentsong" | nc localhost 6600 | grep -e "^Title: ")
   if [ -z "$title" ]   # check if a title was returned
   then
      title="Title: NULL" # no, let the AVR know not to display a title
   fi
   #echo $title
   echo $title > /dev/tts/0     # send it to the AVR for display
   
   sleep 4      # wait a while, this determines the base rate at which
                # the AVR display loops
   
done