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
  Serial.println(RECEIVER()); //TEST ....IF IS WORKING-..SEE THE SERIAL IF THE SENDER-TRANSMITTER WORKS(OF COURSE ACTIVATE THE TRANSMITTER)
  
//ΕΑΝ ΑΝΙΧΝΕΥΤΕΙ ΥΠΕΡΗΧΟΣ ΕΝΕΡΓΟΠΟΙΗΣΗ ΠΧ ΑΝΑΒΩ ΦΩΣ ΚΑΙ BUZZER-IF THIS PARTICULAR ULTRASOUND DETECT then TURN ON THE LEDS AND BUZZER OR WHATEVER YOU WANT 
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

