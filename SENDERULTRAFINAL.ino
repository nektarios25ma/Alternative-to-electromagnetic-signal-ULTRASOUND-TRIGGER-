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

