#! /bin/sh -
# interface.sh - Wifi Radio User Interface Script
# 01/29/09      Jeff Keyzer     http://mightyohm.com
#
# This shell script sets up a playlist in mpd and changes playlist entries
# based on the position of a tuner knob connected to an AVR on the router's
# serial port.
#
# The script expects the AVR to send data at 9600 baud (8N1) to the router,
# in the format "tuner: value", one line at a time.
#
# This script also launches display.sh, the LCD display script.
#
# For more information, visit
# http://mightyohm.com/blog/tag/wifiradio/
#
# This work is protected by the
# Creative Commons Attribution-Share Alike 3.0 United States License.
# http://creativecommons.org/licenses/by-sa/3.0/us/ 

# Some configuration settings
VOLUME=75

trap 'kill $! ; exit 1' SIGINT  # exit on ctrl-c, useful for debugging
                                # kills the display.sh process before exiting

stty 9600 -echo < /dev/tts/0    # set serial port to 9600 baud
                                # so we can talk to the AVR
                                # turn off local echo to make TX/RX directions
                                # completely separate from each other

# mpd setup
mpc volume $VOLUME      # adjust this to suit your speakers/amplifier
mpc clear               # clear current playlist

# build a playlist, substitute your favorite radio stations here
# the first line becomes station #1, and so on.
mpc add http://icecast.bigrradio.com/80s90s                     # Natalie's Fav Big R Radio
mpc add http://scfire-mtc-aa03.stream.aol.com/stream/1075       # Country Hits
mpc add http://Streaming10.radionomy.com/Ambiance-Reggae	# Ambiance Reggae
mpc add http://scfire-ntc-aa07.stream.aol.com:80/stream/2011	# SXSW Radio
mpc add http://66.220.3.52:8030					# 1.FM Blues
mpc add http://scfire-dtc-aa02.stream.aol.com:80/stream/1071	# Hot 108 JAMZ
mpc add http://216.218.147.40:3054				# Big Band Radio
mpc add http://174.36.206.197:8000				# Veince Classic Radio
mpc add http://2503.live.streamtheworld.com/KKNEAMCMP3		# Trad Hawaii
mpc add http://74.63.47.82:8500					# Street Lounge
mpc add http://85.17.26.115:80					# TechnoBase.FM
mpc add http://38.107.220.164:8082				# Christmas Music

# display 
mpc playlist

# Tell the AVR we're ready to start doing stuff
# we do this a few times, if the AVR misses this command
# it will be stuck in a loop...not a good thing... :)
echo "AVR Start!\n" > /dev/tts/0
sleep 1
echo "AVR Start!\n" > /dev/tts/0

# play first stream
#mpc play 1

# launch LCD display routines in the background
/root/display2.sh &

oldStation = 0

while true      # loop forever
do
   inputline="" # clear input
   inputline=$(head -n 1 < /dev/tts/0)
#   echo "mpc play $inputline" > /dev/tts/0
   if [ "$oldStation" -ne "$inputline" ]
   then
        oldStation=$inputline
        mpc play $inputline
   fi
   sleep 1
done