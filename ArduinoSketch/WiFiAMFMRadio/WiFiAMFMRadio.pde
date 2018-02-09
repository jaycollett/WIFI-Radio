// VERSION NOTES
// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// v1.0a : Initial build (01/27/2011)
// v1.1a : Updated radio stations to fix broken ones. Also updated code to work with the new strings library as part of Arduino 0019 and above. (5/27/2011)
// v1.2a : Cleaned up the serialInputString use, tried to limit filling up SRAM with the string which is limited to maxLength now. (5/29/2011)
// v1.3a : Fixed the mysterous crashes (had to due with maxing RAM out on the Arduino). Using PROGMEM to store static strings and switched from int to byte as applicable (6/22/2011)
// v1.4a : Fixed bug with song/artist string not having a hyphen. (6/25/2011)
// v1.5a : Fixed bug where the last char of the song artist/title was cut off (6/25/2011)
// v2.0  : Major revamp of code. Added support for new AM/FM radio chip and interface with new digital encoder. (lot's of todos left in this version)
// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

// Adding the required external libraries
#include <LiquidCrystal.h>
#include <avr/pgmspace.h>
#include <Si4735.h>

// TODO: Move to const instead of defines....
// varibles for encoder port and pins
#define encoder_Pin_A 18
#define encoder_Pin_B 19
#define encoder_Port PINC

// create instance of Si4735 (radio)
Si4735 radio;

// configure any consts
const int8_t enc_states[] = {0,1,-1,0,-1,0,0,1,1,0,0,-1,0,-1,1,0};
const byte maxLength = 160;                   // max length of string from router (helps to protect SRAM fill-ups)
const byte maxCols = 19;                      // zero based number of columns for display
const byte maxRows = 3;                       // zero based number of rows for the display
const byte artistDisplayRow = 1;              // zero based, set to -1 to prevent display
const byte songTitleDisplayRow = 2;           // zero based, set to -1 to prevent display
const byte playListDisplayRow = 3;            // zero based, set to -1 to prevent display, displays current place in playlist
const byte encoderButtonPin = 16;             // analog pin for button presses

// sketch variables
char serialInChar;                            // temp character for reading in serial data
String serialInputString = "";                // set the string to our max length
boolean waitForBoot = true;                   // value to control the boot loop
byte mpcChannel = 0;                          // playlist number from mpc that is currently playing
unsigned long selectorTime;                   // timestamp of selector last move, millis()
char buffer[22];                              // buffer to hold radio stations that are copied over from the program space (used to save RAM)
boolean foundIt = false;                      // boolean to control the looping when we look for "-"'s in the serial string
unsigned int tmpdata = 1;                     // holds the rotary encoder's current state   
static uint8_t counter = 0;                   //this variable will be changed by encoder input
byte radioMode = 0;                           // mode of radio. AM/FM/Wifi (0=WiFi, 1=FM, 2=AM) encoder button will switch this
uint8_t old_AB = 0;                           // variable used to hold the bits from the encoder port for the last reading
unsigned int freqAM = 1040;                   // holds the interger representation of the AM frequency, defaulting to somewhere in the middle of the band
unsigned int freqFM = 9810;                   // holds the interger representation of the FM frequency, defaulting to somewhere in the middle of the band


// custom radio station titles...
// these should be sync'd with the interface.sh script on the router. This allows the display to show the station to the user
// as quickly as they can rotate the rotary switch. I thought this helped keep the user expirence crisp and friendly.
// Loaded the char array into progmem to reduce ram issues which should help with low RAM issues...
const prog_char string_0[] PROGMEM =  "BigR Radio 90's Hits"; 
const prog_char string_1[] PROGMEM =  "Kicking Country Hits";
const prog_char string_2[] PROGMEM =  "Ambiance Reggae";
const prog_char string_3[] PROGMEM =  "SXSW Radio";
const prog_char string_4[] PROGMEM =  "1.FM Blues";
const prog_char string_5[] PROGMEM =  "Hot 108 JAMZ";
const prog_char string_6[] PROGMEM =  "Big Band Radio";
const prog_char string_7[] PROGMEM =  "Veince Classical";
const prog_char string_8[] PROGMEM =  "Traditional Hawaii";
const prog_char string_9[] PROGMEM =  "Street Lounge";
const prog_char string_10[] PROGMEM =  "Electronic House";
const prog_char string_11[] PROGMEM =  "Christmas 24/7";
const prog_char string_12[] PROGMEM =  "Golden Oldies";
const prog_char string_13[] PROGMEM =  "40's and 50's";
const prog_char string_14[] PROGMEM =  "60's and 70's";
const prog_char string_15[] PROGMEM =  "Great 80's";
const prog_char string_16[] PROGMEM =  "Public Radio (NPR)";
const prog_char string_17[] PROGMEM =  "ESPN Radio";
const prog_char string_18[] PROGMEM =  "Top 40";
const prog_char string_19[] PROGMEM =  "Classic Rock";

// array of pointers to the string consts above in PROGMEM
PROGMEM const char *radioStations[] ={
  string_0,
  string_1,
  string_2,
  string_3,
  string_4,
  string_5,
  string_6,
  string_7,
  string_8,
  string_9,
  string_10,
  string_11,
  string_12,
  string_13,
  string_14,
  string_15,
  string_16,
  string_17,
  string_18,
  string_19
};

// initalize the LCD library with the pins used for our display
// CHECK THE PINS FOR YOUR SETUP!
LiquidCrystal lcd(2, 3, 4, 5, 6, 7);

void setup(){
  // set up the LCD's number of rows and columns, I'm using a 20X4 LCD
  lcd.begin((maxCols+1), (maxRows+1));

  // initialize the serial communications:
  Serial.begin(9600);

  // display boot screen with firmware and author info
  lcd.setCursor(0,0);
  lcd.print("Retro WIFI/AM/FM Radio");
  lcd.setCursor(0,1);
  lcd.print("By Jay Collett      ");
  lcd.setCursor(0,2);
  lcd.print("www.jaycollett.com  ");
  lcd.setCursor(0,3);
  lcd.print("Firmware Ver 2.0    ");


  // delay a few seconds to allow the above message to be readable,
  // then show the booting, please wait screen...
  // the router boots fairly slowly, this helps let the end-user
  // know that the system is working, not locked up.
  delay(10000);

  // ok, now display that the router is booting...
  lcd.clear();
  lcd.setCursor(0,1);
  lcd.print("booting router      ");
  lcd.setCursor(0,2);
  lcd.print("this will take time ");

  /* Setup encoder pins as inputs */
  pinMode(encoder_Pin_A, INPUT);
  digitalWrite(encoder_Pin_A, HIGH);
  pinMode(encoder_Pin_B, INPUT);
  digitalWrite(encoder_Pin_B, HIGH);
  pinMode(encoderButtonPin, INPUT);
  digitalWrite(encoderButtonPin, HIGH);
  
  // the interface script on the router will let us
  // know when it's done booting and ready to start
  // talking to the arduino
  waitForRouterBootACK();

} // end of setup method


void loop()
{
  // nice and clean loop method :)

  // method to check user input and determine if the channel selector has been changed.
  processUserInput();

  // method to update the display with data from the display2.sh script running
  // on the router if the radio is in WiFi mode, otherwise leave it alone...
  if(radioMode == 0)
    updateDisplayWithStreamData();
}

// method used to listen to the serial in from the router
// to determine when the router is done booting and ready to start
// doing some communication with the Arduino
void waitForRouterBootACK(){
  while(waitForBoot){ 
    if(Serial.available()){
      while(Serial.available()>0){
        serialInChar = Serial.read();
        if(serialInputString.length() < maxLength){
          serialInputString.concat(serialInChar);
        }else{
          if(serialInputString.indexOf("AVR Start!")>=0){
            // break out of loop and start looking for user input
            // and serial data from router
            waitForBoot = false;
            serialInputString = "";
          }
          serialInputString = "";
        }
      }
      if(serialInputString.indexOf("AVR Start!")>=0){
        // break out of loop and start looking for user input
        // and serial data from router
        waitForBoot = false;
        serialInputString = "";
      }
    }
  } 
}

// pretty simple method to extract the information from the display2.sh serial stream
// and display it as defined on the LCD display
void updateDisplayWithStreamData(){
  // when characters arrive over the serial port...
  if (Serial.available()) {
    // wait a bit for the entire message to arrive
    delay(80);
    // read all the available characters
    while (Serial.available() > 0) {
      // read in the serial char
      serialInChar = Serial.read();
      // check for newline (CRLF) char
      if(serialInChar == '\n'){ 
          // we hit the newline char, process this string   
          // we need to make sure this serial string isn't the radio station but rather the song's artist and title
          if(serialInputString.indexOf("Title: ")>=0){
            // first we need to see if we have NULL in the string, this happens when the router gets invalid data from mpc
            if(serialInputString.indexOf("NULL")>=0){
              serialInputString = "Title: Refreshing Artist - Refreshing Title ";
            }
            
            // parse out the artist and the song title from the router serial input
            // first we parse out the artist info, then the song info (sacraficed some readability/maintainability for lower SRAM usuage)
            // had this as seprate methods, too much SRAM was being used....
            if(artistDisplayRow >= 0){
            // extract the artist name from the string
            // that should contain both the artist name and the song
            // title. Format: artist - song title
            // look through string to find "-" hyphen
            // string will begin with "Title: ", we'll need to account for that
            // maxCols is zero based, our length methods are not, account for that too 
            lcd.setCursor(0,artistDisplayRow);
            foundIt = false;
              for(byte thisChar = 0; thisChar < serialInputString.length(); thisChar++){
               if((serialInputString.charAt(thisChar) == '-') && (!foundIt)){
                 foundIt = true;
                 if( serialInputString.substring(7,thisChar).length() > (maxCols+1)){
                   lcd.print(padAndTrimStringWithSpaces(serialInputString.substring(7,(maxCols+2))));
                 }
                 else{
                   lcd.print(padAndTrimStringWithSpaces(serialInputString.substring(7,thisChar-1)));
                 }
               }
              }
              
              // we didn't find a single "-", it' happens...especially with techno stations...just display the string we get as the artist and the song title
              if(!foundIt){
                foundIt = true;
                lcd.print(padAndTrimStringWithSpaces(serialInputString.substring(7,serialInputString.length())));
              }
            }
  
            // parse out the title of the currently playing song and display it on the LCD
            // if it's enabled
            if(songTitleDisplayRow >= 0){
              // look through the string to find a "-" and then return
              // the remaining string past the "-" which should be the song title
              byte endIndex;
              lcd.setCursor(0,songTitleDisplayRow);
              foundIt = false;
              for(byte thisChar = 0; thisChar < serialInputString.length(); thisChar++){
                if((serialInputString.charAt(thisChar) == '-') && (!foundIt)){
                  foundIt = true;
                  if(serialInputString.substring(thisChar+2).length() > (maxCols+1)){
                    endIndex = (maxCols+1)+(thisChar+2); // the song title is longer than we can show, limit it to the showable length
                  }
                  else{
                    endIndex = serialInputString.length()-1; // the song title is within our showable limits but we must remove the trailing char
                  }
                  lcd.print(padAndTrimStringWithSpaces(serialInputString.substring((thisChar+2),endIndex))); 
                }
              }
              
              // we didn't find a single "-", it' happens...especially with techno stations...just display the string we get as the artist and the song title
              if(!foundIt){
                foundIt = true;
                lcd.print(padAndTrimStringWithSpaces(serialInputString.substring(7)));
              }
              
            }
            
          }
          // clearing the string to free up as much SRAM as possible as soon as possible
          serialInputString = "";   
      }
      else{
        if(serialInputString.length() < maxLength)
          serialInputString.concat(serialInChar); 
      }
    }
  }
  serialInputString = "";
}

// method to check the rotary switch and see if the user has adjusted it
// if so, it waits to see if they are still scrolling or have settled on a 
// station.
void processUserInput(){
  
  // first we determine if the user has hit the encoder button to switch modes?
  // debounce is performed by a maxim debounce IC on the board, neat huh?
  if(digitalRead(encoderButtonPin) == LOW){
      // cycle radio mode
    if(radioMode == 0){
      Serial.println(int(9999)); // in honor of old school mainframe developers, 9999 will tell mpc to stop

      radio.begin(FM);
      radio.tuneFrequency(freqFM);
      
      lcd.setCursor((maxCols-4),playListDisplayRow);
      lcd.print("  FM ");
      
      lcd.setCursor(0,artistDisplayRow);
      lcd.print(padAndTrimStringWithSpaces(""));

      lcd.setCursor(0,songTitleDisplayRow);
      lcd.print(padAndTrimStringWithSpaces(""));
      
      radioMode = 1;
  }else if(radioMode == 1){
      radio.begin(AM);
      radio.tuneFrequency(freqAM);

      lcd.setCursor((maxCols-4),playListDisplayRow);
      lcd.print("  AM ");
      
      lcd.setCursor(0,artistDisplayRow);
      lcd.print(padAndTrimStringWithSpaces(""));

      lcd.setCursor(0,songTitleDisplayRow);
      lcd.print(padAndTrimStringWithSpaces(""));

      radioMode = 2; 
    }else{
      radio.mute(); // may need radio.end() not sure which is best here, had issues with radio.end when switching between am/fm
      
      // set the display back to the wifi mode....
      lcd.clear();
      lcd.setCursor(0,0);
      strcpy_P(buffer, (char*)pgm_read_word(&(radioStations[mpcChannel-1]))); // Necessary casts and dereferencing
      lcd.print(padAndTrimStringWithSpaces(buffer)); 
      lcd.setCursor(0,playListDisplayRow);
      if(mpcChannel < 10){
        lcd.setCursor((maxCols-3),playListDisplayRow);
      }
      else{
        lcd.setCursor((maxCols-4),playListDisplayRow);
      }
      lcd.print(int(mpcChannel));
      lcd.setCursor((maxCols-2),playListDisplayRow);
      lcd.print("/20");
      
      // and now start playing the last station we were playing before switching radio modes
      Serial.println(int(mpcChannel));
      radioMode = 0; 
    }  
  }

  // now we perform different logic based on radioMode
  if(radioMode == 0){
    
    // checking to see if the user changed the station dial
    // if so, update screen with station selected and then 
    // send commands to router if the user has left
    // the selector idle for 2 seconds. This will 
    // prevent flooding the router with commands....
    byte mpcChannelNew = getRotaryEncoderValue();
  
    // well the selector has changed, but is the user
    // flipping through channels or have they left the selector on 
    // this station to play? Good question, let's check back again in 
    // 2000ms and if they have left it here, let's tell the routher
    // to play this station, otherwise, they are just playing with the knob.. :)
    if(mpcChannelNew != mpcChannel){
      // grab the current timestamp
      selectorTime = millis();
      mpcChannel = mpcChannelNew;
  
      // as the selector is changing, show the radio station.
      // this data comes from our custom radio station names array we defined
      // at the start of this sketch
      lcd.clear();
      lcd.setCursor(0,0);
      strcpy_P(buffer, (char*)pgm_read_word(&(radioStations[mpcChannel-1]))); // Necessary casts and dereferencing
      lcd.print(padAndTrimStringWithSpaces(buffer)); 
      lcd.setCursor(0,playListDisplayRow);
      if(mpcChannel < 10){
        lcd.setCursor((maxCols-3),playListDisplayRow);
      }
      else{
        lcd.setCursor((maxCols-4),playListDisplayRow);
      }
      lcd.print(int(mpcChannel));
      lcd.setCursor((maxCols-2),playListDisplayRow);
      lcd.print("/20");
    }
    else{
      // let's check to see if we need to process a channel change, otherwise,
      // the knob has been left here and we are already playing the station...
      if(selectorTime != 0){
        if((millis()-selectorTime) >= 2000){
          // ok, they seem to have quit playing with the knob, let's change the
          // music station on the router... 
          selectorTime = 0;
          Serial.println(int(mpcChannel));
          lcd.setCursor(0,0);
          strcpy_P(buffer, (char*)pgm_read_word(&(radioStations[mpcChannel-1]))); // Necessary casts and dereferencing
          lcd.print(padAndTrimStringWithSpaces(buffer)); 
        }
      }
    }
  }else if(radioMode == 1){
    // TODO: Evaluate moving this to a interrupt
    switch(read_encoder()){
      case 0: 
        break;
      case 1:
        freqFM += 20;
        radio.tuneFrequency(freqFM);
        break;   
      case -1:
        freqFM -= 20;
        radio.tuneFrequency(freqFM);
        break;
    }
    lcd.setCursor(0,0);
    lcd.print("                    ");
    lcd.setCursor(0,songTitleDisplayRow);
    lcd.print("        ");
    // formatting our freq to have the decimal (makes it easier to read and is a standard display format)
    lcd.print(freqFM/100);
    lcd.print(".");
    lcd.print((freqFM%100)/10);
    lcd.print("       ");

  }else if(radioMode == 2){
    // TODO: Evaluate moving this to a interrupt    
    switch(read_encoder()){
      case 0:
        break;
      case 1:
        freqAM += 10;
        radio.tuneFrequency(freqAM);
        break;   
      case -1:
        freqAM -= 10;
        radio.tuneFrequency(freqAM);
        break;
    }
    lcd.setCursor(0,0);
    lcd.print("                    ");
    lcd.setCursor(0,songTitleDisplayRow);
    lcd.print("       ");
    lcd.print(freqAM);
    lcd.print("     ");
  }
}

// pad the end of the string to fill maxcols of LCD, will clear
// out the display without the blinking of lcd.clear()
String padAndTrimStringWithSpaces(String tmpString){
  tmpString.trim();
  if(tmpString.length() > maxCols+1){
    tmpString.substring(0,maxCols+1); 
  }
  else{
    while(tmpString.length() < maxCols+1){
      tmpString.concat(" ");
    } 
  }
  return tmpString;
}

// method to return the current position of the rotary encoder
byte getRotaryEncoderValue(){
  tmpdata = read_encoder();

  if( tmpdata ) {
    counter += tmpdata;
  }
  // setup scaled counter
  return (map(counter,0,256,1,21));
}

/* returns change in encoder state (-1,0,1) */
int8_t read_encoder()
{
  uint8_t new_AB = encoder_Port;
  
  new_AB >>=4;       // shift our new encoder bits right 4 places to put them in the lowest two bit positions
  old_AB <<=2;       // shift our bits left two places so we remember the current encoder values
  
  old_AB |= ( new_AB & 0x03); // add current readings and zero out all but bits 0 through 3
  
  return ( enc_states[( old_AB & 0x0f )]);
}

