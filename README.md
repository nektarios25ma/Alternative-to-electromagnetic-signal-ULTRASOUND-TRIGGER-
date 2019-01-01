# Alternative-to-electromagnetic-switch-ULTRASOUND-TRIGGER-
Alternative to electromagnetic signal-ULTRASOUND TRIGGER THAT ACTIVATE THE LIGHTS-ALARM OR WHATEVER YOU WANT
Trying to activate a lights,alarm wireless with the basic arduino kit, i create a specific ultrasound signal with HC-SR04.
This will be used to a school project as a part of smart city miniature and "priority" to ambulance of blocked roads with traffic lights
First the code of transmitter:
#define TRIGGERPIN 8 
#define ECHOPIN 9
void setup() {
  pinMode(TRIGGERPIN,OUTPUT);
  pinMode(ECHOPIN,INPUT);
  
}

void loop()  {
  digitalWrite(TRIGGERPIN,LOW);
  delayMicroseconds(1);
  digitalWrite(TRIGGERPIN,HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIGGERPIN,LOW);
  delayMicroseconds(1);
  
} 
Then the code of receiver:
#define echo 12
#define trigger 13
int ledRed = 2; 
int ledOrange = 10; 
int ledGreen = 9; 
const int buzzer = 7;
long RECEIVER()     //Η ΣΚΑΝΔΑΛΗ ΠΟΥ ΣΤΕΛΝΕΙ ΨΕΥΔΩΣ ΥΠΕΡΗΧΗΤΙΚΟ ΣΗΜΑ ΓΙΑ ΝΑ ΕΝΕΡΓΟΠΟΙΗΘΕΙ ΟΥΣΙΑΣΤΙΚΑ Ο ΔΕΚΤΗΣ-THE TRIGGER SEND A BLIND SIGNAL TO ACTUALLY TURN ON THE RECEIVER-ECHO
{
 digitalWrite(trigger,LOW);
  delayMicroseconds(2);
  digitalWrite(trigger,HIGH);
  delayMicroseconds(2);
  digitalWrite(trigger,LOW);
  delayMicroseconds(2);
  long microseconds=pulseIn(echo,HIGH,100000);
  return microseconds / 10;
}
  
void setup(){
  pinMode(echo,INPUT);
  pinMode(trigger,OUTPUT);
  pinMode(ledRed, OUTPUT); 
  pinMode(ledOrange, OUTPUT);
  pinMode(ledGreen, OUTPUT); 
  pinMode(buzzer,OUTPUT);
  Serial.begin(9600);
}
void loop(){
  delay(50);
  Serial.println(RECEIVER()); //TEST ....IF IS WORKING-SEE THE SERIAL IF THE SENDER-TRANSMITTER WORKS(OF COURSE ACTIVATE THE TRANSMITTER)
  
//ΕΑΝ ΑΝΙΧΝΕΥΤΕΙ ΥΠΕΡΗΧΟΣ ΕΝΕΡΓΟΠΟΙΗΣΗ ΠΧ ΑΝΑΒΩ ΦΩΣ ΚΑΙ BUZZER-IF THIS PARTICULAR ULTRASOUND DETECT WHILE TURN ON THE LEDS AND BUZZER OR WHATEVER YOU WANT 
  if ( RECEIVER()>= 5 && RECEIVER()<= 29930) {
    digitalWrite(ledOrange, HIGH);
    digitalWrite(ledGreen, HIGH);
    digitalWrite(ledRed, HIGH);
    tone(buzzer,1000);
    delay(400);   
  }
  else {digitalWrite(ledRed, LOW); 
  digitalWrite(ledOrange, LOW); 
  digitalWrite(ledGreen, LOW);
  noTone(buzzer);}
  //WITH NO SIGNAL THE RECEIVER WRITES ZERO 
 if ( RECEIVER()<= 5 ) { 
  digitalWrite(ledOrange, LOW);
  digitalWrite(ledGreen, LOW);
  digitalWrite(ledRed, LOW);
  noTone(buzzer);   
  }
  
 
}
