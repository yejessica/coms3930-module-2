const int xPin = 39;
const int yPin = 32;
const int joystickButtonPin = 33;
const int potPin = 36;
const int buttonPin = 2;
const int ledPin = 15;
const unsigned long shieldDurationMs = 5000;
const unsigned long shieldCooldownMs = 30000;
const unsigned long debounceMs = 30;
int lastButtonReading = HIGH;
int buttonState = HIGH;
unsigned long buttonChangedAt = 0;
unsigned long shieldStartedAt = 0;
bool shieldActive = false;
bool shieldCycleActive = false;

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

  unsigned long now = millis();
  if (shieldCycleActive && now - shieldStartedAt >= shieldDurationMs + shieldCooldownMs) {
    shieldCycleActive = false;
  }
  while (Serial.available() > 0) {
    int command = Serial.read();
    if (command == 'R') {
      shieldStartedAt = 0;
      shieldActive = false;
      shieldCycleActive = false;
      digitalWrite(ledPin, LOW);
      lastButtonReading = buttonVal;
      buttonState = buttonVal;
      buttonChangedAt = now;
      Serial.println("R");
    } else if ((command == 'S' || command == 's') && !shieldCycleActive) {
      shieldStartedAt = now;
      shieldCycleActive = true;
    }
  }
  if (buttonVal != lastButtonReading) {
    buttonChangedAt = now;
  }
  lastButtonReading = buttonVal;
  if (now - buttonChangedAt >= debounceMs && buttonVal != buttonState) {
    buttonState = buttonVal;
    if (buttonState == LOW && !shieldCycleActive) {
      shieldStartedAt = now;
      shieldCycleActive = true;
    }
  }
  unsigned long elapsed = now - shieldStartedAt;
  shieldActive = shieldCycleActive && elapsed < shieldDurationMs;
  unsigned long shieldRemainingMs;
  if (shieldActive) {
    shieldRemainingMs = shieldDurationMs - elapsed;
  } else {
    shieldRemainingMs = 0;
  }
  unsigned long cooldownRemainingMs;
  if (shieldCycleActive && !shieldActive) {
    cooldownRemainingMs = shieldDurationMs + shieldCooldownMs - elapsed;
  } else {
    cooldownRemainingMs = 0;
  }
  int ledState;
  if (shieldActive) {
    ledState = HIGH;
  } else {
    ledState = LOW;
  }
  digitalWrite(ledPin, ledState);

  // Output: X,Y,joystickButton,potentiometer,pushbutton,LED,shieldRemainingMs,cooldownRemainingMs
  Serial.printf("%d,%d,%d,%d,%d,%d,%lu,%lu\n",
                xVal,
                yVal,
                joystickButtonVal,
                potVal,
                buttonState,
                ledState,
                shieldRemainingMs,
                cooldownRemainingMs);

  delay(20);
}
