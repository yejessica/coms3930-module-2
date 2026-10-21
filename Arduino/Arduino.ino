const int xPin = 39;
const int yPin = 32;
const int joystickButtonPin = 33;
const int potPin = 36;
const int buttonPin = 2;
const int ledPin = 15;

void setup() {
  Serial.begin(9600);

  pinMode(joystickButtonPin, INPUT_PULLUP);
  pinMode(buttonPin, INPUT_PULLUP);
  pinMode(ledPin, OUTPUT);

  digitalWrite(ledPin, LOW);
}

void loop() {
  int xVal = analogRead(xPin);
  int yVal = analogRead(yPin);
  int joystickButtonVal = digitalRead(joystickButtonPin);
  int potVal = analogRead(potPin);
  int buttonVal = digitalRead(buttonPin);

  // Button reads LOW (0) when pressed.
  int ledState = (buttonVal == LOW) ? HIGH : LOW;
  digitalWrite(ledPin, ledState);

  // Output: X,Y,joystickButton,potentiometer,pushbutton,LED
  Serial.printf("%d,%d,%d,%d,%d,%d\n",
                xVal,
                yVal,
                joystickButtonVal,
                potVal,
                buttonVal,
                ledState);

  delay(20);
}