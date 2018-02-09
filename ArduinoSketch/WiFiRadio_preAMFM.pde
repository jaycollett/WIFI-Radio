// VERSION NOTES
// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// v1.0a : Initial build (01/27/2011)
// v1.1a : Updated radio stations to fix broken ones. Also updated code to work with the new strings library as part of Arduino 0019 and above. (5/27/2011)
// v1.2a : Cleaned up the serialInputString use, tried to limit filling up SRAM with the string which is limited to maxLength now. (5/29/2011)
// v1.3a : Fixed the mysterous crashes (had to due with maxing RAM out on the Arduino). Using PROGMEM to store static strings and switched from int to byte as applicable (6/22/2011)
// v1.4a : Fixed bug with song/artist string not having a hyphen. (6/25/2011)
// v1.5a : Fixed bug where the last char of the song artist/title was cut off (6/25/2011)
// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

// Adding the required external libraries
#include <LiquidCrystal.h>
#include <avr/pgmspace.h>


// configure any consts

const byte maxLength = 160;         // max length of string from router (helps to protect SRAM fill-ups)
const byte maxCols = 19;            // zero based number of columns for display
const byte maxRows = 3;             // zero based number of rows for the display
const byte artistDisplayRow = 1;    // zero based, set to -1 to prevent display
const byte songTitleDisplayRow = 2; // zero based, set to -1 to prevent display
const byte analogChannel1 = 0;      // analog channel 1's pin number
const byte playListDisplayRow = 3;  // zero based, set to -1 to prevent display, displays current place in playlist


// sketch variables
char serialInChar;                            // temp character for reading in serial data
String serialInputString = "";                // set the string to our max length
boolean waitForBoot = true;                   // value to control the boot loop
byte selectorValue = 0;                       // analog value read from our 12 position rotary switch
byte mpcChannel = 0;                          // playlist number from mpc that is currently playing
unsigned long selectorTime;                   // timestamp of selector last move, millis()
char buffer[22];                              // buffer to hold radio stations that are copied over from the program space (used to save RAM)
boolean foundIt = false;                      // boolean to control the looping when we look for "-"'s in the serial string


// custom radio station titles...
// these should be sync'd with the interface.sh script on the router. This allows the display to show the station to the user
// as quickly as they can rotate the rotary switch. I thought this helped keep the user expirence crisp and friendly.
// Loaded the char array into progmem to reduce ram issues which should help with low RAM issues...
const prog_char string_0[] PROGMEM =  "BigR Best of 80's"; 
const prog_char string_1[] PROGMEM =  "Kicking Country Hits";
const prog_char string_2[] PROGMEM =  "Ambiance Reggae";
const prog_char string_3[] PROGMEM =  "SXSW Radio";
const prog_char string_4[] PROGMEM =  "1.FM Blues";
const prog_char string_5[] PROGMEM =  "Hot 108 JAMZ";
const prog_char string_6[] PROGMEM =  "Big Band Radio";
const prog_char string_7[] PROGMEM =  "Veince Classical";
const prog_char string_8[] PROGMEM =  "Traditional Hawaii";
const prog_char string_9[] PROGMEM =  "Street Lounge";
const prog_char string_10[] PROGMEM =  "TechnoBase.FM";
const prog_char string_11[] PROGMEM =  "Christmas Music";

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
  string_11
};

// initalize the LCD library with the pins used for our display
// CHECK THE PINS FOR YOUR SETUP!
LiquidCrystal lcd(7, 8, 9, 10, 11, 12);

void setup(){
  // set up the LCD's number of rows and columns, I'm using a 20X4 LCD
  lcd.begin((maxCols+1), (maxRows+1));

  // initialize the serial communications:
  Serial.begin(9600);

  // display boot screen with firmware and author info
  lcd.setCursor(0,0);
  lcd.print("Retro WIFI Radio    ");
  lcd.setCursor(0,1);
  lcd.print("By Jay Collett      ");
  lcd.setCursor(0,2);
  lcd.print("www.jaycollett.com  ");
  lcd.setCursor(0,3);
  lcd.print("Firmware Ver 1.5a   ");


  // delay a few seconds to allow the above message to be readable,
  // then show the booting, please wait screen...
  // the router boots fairly slowly, this helps let the end-user
  // know that the system is working, not locked up.
  delay(8000);

  // ok, now display that the router is booting...
  lcd.clear();
  lcd.setCursor(0,1);
  lcd.print("booting router      ");
  lcd.setCursor(0,2);
  lcd.print("this will take time ");

  // the interface script on the router will let us
  // know when it's done booting and ready to start
  // talking to the arduino
  waitForRouterBootACK();

} // end of setup method


void loop()
{
  // nice and clean loop method :)

  // method to update the display with data from the display2.sh script running
  // on the router
  updateDisplayWithStreamData();

  // method to check user input and determine if the channel selector has been changed.
  processUserInput();
}

// method used to listen to the serial in from the router
// to determine when the router is done booting and ready to start
// doing some communication with the Arduino
void waitForRouterBootACK(){
  while(waitForBoot){ 
    if(Serial.available()){
      while(Serial.available()>0){
        serialInChar = Serial.read();
        if(serialInputString.length() < maxLength)
          serialInputString.concat(serialInChar);
        else{
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
  // checking to see if the user changed the station dial
  // if so, update screen with station selected and then 
  // send commands to router if the user has left
  // the selector idle for 1.5 seconds. This will 
  // prevent flooding the router with commands....
  byte mpcChannelNew = 0;
  // check ADC 0 for input values...
  mpcChannelNew = getSelectorValue();

  // well the selector has changed, but is the user
  // flipping through channels or have they left the selector on 
  // this station to play? Good question, let's check back again in 
  // 1200ms and if they have left it here, let's tell the routher
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
    lcd.print("/12");
  }
  else{
    // let's check to see if we need to process a channel change, otherwise,
    // the knob has been left here and we are already playing the station...
    if(selectorTime != 0){
      if((millis()-selectorTime) >= 1200){
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
}

// method to pass back just the station name, without "Name:"
//String extractStationName(String tmpString){
//  byte endIndex;
//  if(tmpString.length() > (maxCols+7)){
//    endIndex =  (maxCols+7);
//  }
//  else{
//    endIndex = tmpString.length();
//  }
//  return tmpString.substring(6,endIndex);
//}

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

// method to return the current position of the selector knob
byte getSelectorValue(){
 
  // declare local vars
  byte aPin0Value;
  byte aPin1Value;
  byte aPin2Value;
  byte aPin3Value;
  byte selectedPin;
  byte foundSelectedPin = 0; 
  boolean invalidSelectorValue;
  
  invalidSelectorValue = true;
  while(invalidSelectorValue){
    // read all 4 analog pins to see where the selector is
    aPin0Value = analogRead(0);
    aPin1Value = analogRead(1);
    aPin2Value = analogRead(2);
    aPin3Value = analogRead(3);
    
    // now check all channels to see where the selector is
    if((aPin0Value != 0) && (foundSelectedPin != 1)){
      foundSelectedPin = 1;
      if(aPin0Value <=7)
        selectedPin = 3;
      if((aPin0Value < 25) && (aPin0Value > 7))
        selectedPin = 2;
      if(aPin0Value >= 25)
        selectedPin = 1;
    }
    if((aPin1Value != 0) && (foundSelectedPin != 1)){
      foundSelectedPin = 1;
       if(aPin1Value <=7)
        selectedPin = 6;
      if((aPin1Value < 25) && (aPin1Value > 7))
        selectedPin = 5;
      if(aPin1Value >= 25)
        selectedPin = 4;
    }
    if((aPin2Value != 0) && (foundSelectedPin != 1)){
      foundSelectedPin = 1;
       if(aPin2Value <=7)
        selectedPin = 9;
      if((aPin2Value < 25) && (aPin2Value > 7))
        selectedPin = 8;
      if(aPin2Value >= 25)
        selectedPin = 7;
    }
    if((aPin3Value != 0) && (foundSelectedPin != 1)){
      foundSelectedPin = 1;
       if(aPin3Value <=7)
        selectedPin = 12;
      if((aPin3Value < 25) && (aPin3Value > 7))
        selectedPin = 11;
      if(aPin3Value >= 25)
        selectedPin = 10;
    }
    if((selectedPin >= 1) && (selectedPin < 13))
     invalidSelectorValue = false;
  }
  return selectedPin;
}

