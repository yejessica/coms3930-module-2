import processing.serial.*;

// serial connection
final int SERIAL_PORT_INDEX = -1;
Serial myPort;
String connectionStatus = "Keyboard mode";
int lastSerialTime = -1;

// joystick controls
final float JOYSTICK_DEAD_ZONE = 0.15;
final int UP_THRESHOLD = 1400;
final int RELEASE_THRESHOLD = 1800;
float potentiometer = 2047.5;
float joystickX = 0;
boolean joystickUp = false;
boolean joystickDown = false;
int restartXDirection = 0;
int restartYDirection = 0;

// keyboard controls
boolean keyboardUp = false;
boolean keyboardDown = false;
boolean keyboardLeft = false;
boolean keyboardRight = false;
boolean keyboardShield = false;

// fonts and images for the instructions
PFont regularFont;
PFont boldFont;
PImage[] dinoFrames = new PImage[2];
PImage[] duckFrames = new PImage[2];
PImage dinoEnd;
PImage duckEnd;
PImage[] pterodactylFrames = new PImage[2];
PImage[] cactusSprites = new PImage[9];

// game state 
final int INSTRUCTIONS_DURATION_MS = 5000;
boolean gameOver = false;
boolean diedDucking = false;
int instructionsStartedAt;
int lastFrameTime;
float elapsedRunTime = 0;
float distance = 0;
int score = 0;

// dino movement 
final float GROUND_Y = 300;
final float DINO_X = 120;
final float DINO_HEIGHT = 86;
final float RUN_ANIMATION_FPS = 12;
final float GRAVITY = 1700;
final float JUMP_SPEED = 660;
float jumpHeight = 0;
float jumpVelocity = 0;
float animationTime = 0;

// Running speed
final float RUN_SPEED = 280;
final float MIN_SPEED = 80;
final float MAX_SPEED = 600;
final float SPEED_INCREASE_PER_SECOND = 0.5;
final float MAX_TIME_SPEED_BONUS = 200;
float currentSpeed = RUN_SPEED;

// obstacles
final float CACTUS_HEIGHT = 50;
final float PTERODACTYL_WIDTH = 60;
final float LOW_BIRD_MAX_HEIGHT = 50;
final float FLAP_FPS = 6;
final float OBSTACLE_RAMP_SECONDS = 180;
ArrayList<Obstacle> obstacles = new ArrayList<Obstacle>();
float nextObstacleDistance = 250;

// shield and cooldown
final int SHIELD_DURATION_MS = 5000;
final int SHIELD_COOLDOWN_MS = 30000;
float shieldRemainingMs = 0;
float cooldownRemainingMs = 0;
int shieldUpdatedAt = 0;
int keyboardShieldStartedAt = -1;
boolean shieldResetPending = false;

void setup() {
  size(900, 400);
  noSmooth();
  frameRate(60);
  surface.setTitle("Dino Runner");
  dinoFrames[0] = loadImage("dino1.png");
  dinoFrames[1] = loadImage("dino2.png");
  duckFrames[0] = loadImage("dino_ducking1.png");
  duckFrames[1] = loadImage("dino_ducking2.png");
  dinoEnd = loadImage("dino_end.png");
  duckEnd = loadImage("dino_ducking_end.png");
  pterodactylFrames[0] = loadImage("pterodactyl1.png");
  pterodactylFrames[1] = loadImage("pterodactyl2.png");
  for (int i = 0; i < cactusSprites.length; i++) {
    cactusSprites[i] = loadImage("cacti" + (i + 1) + ".png");
  }
  regularFont = createFont("Monospaced", 14);
  boldFont = new PFont(new java.awt.Font("Monospaced", java.awt.Font.BOLD, 14), true);
  textFont(regularFont);
  connectJoystick();
  lastFrameTime = millis();
  instructionsStartedAt = millis();
}

void connectJoystick() {
  String[] ports = Serial.list();
  printArray(ports);
  int chosenPort = SERIAL_PORT_INDEX;
  if (chosenPort < 0) {
    for (int i = 0; i < ports.length; i++) {
      String name = ports[i].toLowerCase();
      if (name.contains("cu.usb") || name.contains("cu.wch") ||
          name.contains("ttyusb") || name.contains("ttyacm") ||
          name.startsWith("com")) {
        chosenPort = i;
        break;
      }
    }
  }
  if (chosenPort < 0 || chosenPort >= ports.length) {
    connectionStatus = "No board found — use arrow keys / Space";
    return;
  }
  try {
    myPort = new Serial(this, ports[chosenPort], 9600);
    myPort.clear();
    connectionStatus = "Waiting for joystick data";
    println("Connected to " + ports[chosenPort]);
  }
  catch (RuntimeException error) {
    connectionStatus = "Port unavailable — close Serial Monitor; keyboard works";
    println(error.getMessage());
    myPort = null;
  }
}

void readJoystick() {
  if (myPort == null) {
    return;
  }
  while (myPort.available() > 0) {
    String line = myPort.readStringUntil('\n');
    if (line == null) {
      break; 
    }
    line = trim(line);
    if (line.equals("R")) {
      shieldResetPending = false;
      continue;
    }
    String[] values = split(line, ',');
    if (values.length != 8) {
      continue;
    }
    float rawX = parseFloat(values[0]);
    float rawY = parseFloat(values[1]);
    float rawPot = parseFloat(values[3]);
    float remaining = parseFloat(values[6]);
    float cooldown = parseFloat(values[7]);
    if (Float.isNaN(rawX) || Float.isNaN(rawY) || Float.isNaN(rawPot) ||
        Float.isNaN(remaining) || Float.isNaN(cooldown)) {
      continue;
    }
    handleRestartControls(rawX, rawY);
    potentiometer = rawPot;
    float x = map(rawX, 0, 4095, -1, 1);
    if (abs(x) <= JOYSTICK_DEAD_ZONE) {
      joystickX = 0;
    } else {
      float direction;
      if (x < 0) {
        direction = -1;
      } else {
        direction = 1;
      }
      joystickX = direction * (abs(x) - JOYSTICK_DEAD_ZONE) / (1 - JOYSTICK_DEAD_ZONE);
    }
    lastSerialTime = millis();
    connectionStatus = "Joystick connected";
    if (!shieldResetPending) {
      if (trim(values[5]).equals("1")) {
        shieldRemainingMs = remaining;
      } else {
        shieldRemainingMs = 0;
      }
      cooldownRemainingMs = cooldown;
      shieldUpdatedAt = millis();
    }
    if (!joystickDown && rawY > 4095 - UP_THRESHOLD) {
      joystickDown = true;
    } else if (joystickDown && rawY < 4095 - RELEASE_THRESHOLD) {
      joystickDown = false;
    }
    if (!joystickUp && rawY < UP_THRESHOLD) {
      joystickUp = true;
      jump();
    } else if (joystickUp && rawY > RELEASE_THRESHOLD) {
      joystickUp = false;
    }
  }
  if (lastSerialTime >= 0 && millis() - lastSerialTime > 1500) {
    joystickUp = false;
    joystickDown = false;
    joystickX = 0;
    connectionStatus = "No recent joystick data — keyboard works";
  }
}

int inputDirection(float value, int previous) {
  if (value < UP_THRESHOLD) return -1;
  if (value > 4095 - UP_THRESHOLD) return 1;
  if (previous == -1 && value <= RELEASE_THRESHOLD) return -1;
  if (previous == 1 && value >= 4095 - RELEASE_THRESHOLD) return 1;
  return 0;
}

void handleRestartControls(float rawX, float rawY) {
  int xDirection = inputDirection(rawX, restartXDirection);
  int yDirection = inputDirection(rawY, restartYDirection);
  boolean moved = (xDirection != 0 && xDirection != restartXDirection) ||
    (yDirection != 0 && yDirection != restartYDirection);
  restartXDirection = xDirection;
  restartYDirection = yDirection;
  if (gameOver && moved) {
    restartGame();
  }
}

void draw() {
  int now = millis();
  float dt = constrain((now - lastFrameTime) / 1000.0, 0, 0.05);
  lastFrameTime = now;
  readJoystick();
  if (!gameOver) {
    elapsedRunTime += dt;
    float timeSpeedBonus = min(elapsedRunTime * SPEED_INCREASE_PER_SECOND, MAX_TIME_SPEED_BONUS);
    float baseSpeed = map(potentiometer, 0, 4095, 400, 160) + timeSpeedBonus;
    float speedInput = joystickX;
    if (keyboardRight) {
      speedInput += 1;
    }
    if (keyboardLeft) {
      speedInput -= 1;
    }
    speedInput = constrain(speedInput, -1, 1);
    float targetSpeed = constrain(baseSpeed * (1 + 0.5 * speedInput), MIN_SPEED, MAX_SPEED);
    currentSpeed = lerp(currentSpeed, targetSpeed, 1 - exp(-8 * dt));
    animationTime += dt * currentSpeed / RUN_SPEED;
    distance += currentSpeed * dt;
    score = int(distance / 10); 
    updateObstacle(dt);
    if (joystickUp || keyboardUp) {
      jump();
    }
    if (jumpHeight > 0 || jumpVelocity > 0) {
      jumpHeight += jumpVelocity * dt;
      jumpVelocity -= GRAVITY * dt;
      if (jumpHeight <= 0) {
        jumpHeight = 0;
        jumpVelocity = 0;
      }
    }
    checkCollisions();
  }

  background(250);
  drawCloud(220 - (distance * 0.15) % 1100, 95);
  drawCloud(710 - (distance * 0.15) % 1100, 135);
  drawGround();
  for (Obstacle obstacle : obstacles) obstacle.display();
  dinoPose().display();
  if (shieldTimeLeft() > 0) {
    pushStyle();
    noStroke();
    fill(118, 210, 255, 38);
    rect(0, 0, width, height);
    popStyle();
  }
  fill(85);
  textAlign(LEFT);
  boolean showInstructions = millis() - instructionsStartedAt < INSTRUCTIONS_DURATION_MS;
  if (showInstructions) {
    text("Move joystick up to jump, down to duck.", 28, 36);
    text("Move joystick left to slow down, right to speed up.", 28, 58);
    text("Use potentiometer to adjust base speed.", 28, 80);
    text("Keyboard: Space / Up Arrow to jump, Down Arrow to duck.", 28, 102);
  }
  textAlign(RIGHT);
  fill(55);
  drawLabeledValue("SCORE", str(score), width - 28, 36);
  drawLabeledValue("SPEED", str(round(currentSpeed)), width - 28, 58);
  textFont(regularFont);
  float shieldSeconds = shieldTimeLeft() / 1000.0;
  if (shieldSeconds > 0) {
    fill(30, 155, 200);
    text("SHIELD " + ceil(shieldSeconds) + "s", width - 28, 80);
  } else if (cooldownTimeLeft() > 0) {
    fill(170, 120, 60);
    text("COOLDOWN " + ceil(cooldownTimeLeft() / 1000.0) + "s", width - 28, 80);
  } else {
    fill(30, 155, 100);
    text("SHIELD READY", width - 28, 80);
  }
  textAlign(LEFT);
  fill(140);
  textSize(12);
  if (showInstructions) {
    text(connectionStatus, 28, height - 24);
  }
  textSize(14);
  if (gameOver) {
    pushStyle();
    textAlign(CENTER);
    fill(55);
    textSize(32);
    text("GAME OVER", width / 2, 150);
    textSize(14);
    text("Move the joystick or press Space to start a new game", width / 2, 178);
    popStyle();
  }
}

void drawLabeledValue(String label, String value, float right, float y) {
  pushStyle();
  textAlign(RIGHT);
  textFont(regularFont);
  float valueWidth = textWidth(value);
  float gap = textWidth(" ");
  text(value, right, y);
  textFont(boldFont);
  text(label, right - valueWidth - gap, y);
  popStyle();
}

void updateObstacle(float dt) {
  for (int i = obstacles.size() - 1; i >= 0; i--) {
    Obstacle obstacle = obstacles.get(i);
    obstacle.x -= currentSpeed * dt;
    obstacle.flapTime += dt;
    if (obstacle.x + obstacle.displayWidth() < 0) {
      obstacles.remove(i);
    }
  }
  if (distance < nextObstacleDistance) {
    return;
  }
  // 0 is pterodactyl and 1 is cactus
  int obstacleType = int(random(2)); 
  obstacles.add(createObstacle(obstacleType));
  float progression = constrain(elapsedRunTime / OBSTACLE_RAMP_SECONDS, 0, 1);
  float gap = random(lerp(650, 380, progression), lerp(950, 600, progression));
  nextObstacleDistance = distance + max(gap, currentSpeed * 0.9);
}

Obstacle createObstacle(int obstacleType) {
    if (obstacleType == 1) {
      return new Obstacle(obstacleType, GROUND_Y);
    }
    float tallestFrame = PTERODACTYL_WIDTH *
      max(pterodactylFrames[0].height, pterodactylFrames[1].height) /
      max(pterodactylFrames[0].width, pterodactylFrames[1].width);
    float footY;
    float flightType = random(1);
    if (flightType < 0.45) {
      float maxFootHeight = max(0, LOW_BIRD_MAX_HEIGHT - tallestFrame);
      footY = GROUND_Y - random(maxFootHeight);
    } else if (flightType < 0.90) {
      footY = GROUND_Y - 64;
    } else {
      footY = GROUND_Y - 155;
    }
    return new Obstacle(obstacleType, footY);
}

class Obstacle {
  int type;
  PImage cactus;
  float x;
  float footY;
  float flapTime = random(1);

  Obstacle(int obstacleType, float level) {
    type = obstacleType;
    x = width + 20;
    footY = level;
    if (type == 1) {
      cactus = cactusSprites[int(random(cactusSprites.length))];
    }
  }

  float displayWidth() {
    if (type == 1) {
      return CACTUS_HEIGHT * cactus.width / cactus.height;
    } else {
      return PTERODACTYL_WIDTH;
    }
  }

  SpritePose pose() {
    // simple case of a cactus
    if (type == 1) {
      return new SpritePose(cactus, x, GROUND_Y - CACTUS_HEIGHT,
        displayWidth(), CACTUS_HEIGHT, false);
    }
    PImage sprite = pterodactylFrames[int(flapTime * FLAP_FPS) % 2];
    // scaling for the pterodactyl
    float spriteScale = PTERODACTYL_WIDTH /
      max(pterodactylFrames[0].width, pterodactylFrames[1].width);
    float w = sprite.width * spriteScale;
    float h = sprite.height * spriteScale;
    return new SpritePose(sprite, x, footY - h, w, h, true);
  }

  void display() {
    pose().display();
  }
}

void drawGround() {
  stroke(120);
  strokeWeight(1);
  line(0, GROUND_Y, width, GROUND_Y);
  for (int i = 0; i < 24; i++) {
    float x = i * 47 - distance % 47;
    float y = GROUND_Y + 7 + (i % 3) * 6;
    line(x, y, x + 4 + (i % 4) * 3, y);
  }
}

void drawCloud(float x, float y) {
  if (x < -100) {
    x += 1100;
  }
  noFill();
  stroke(220);
  strokeWeight(2);
  beginShape();
  vertex(x, y);
  vertex(x + 15, y);
  vertex(x + 15, y - 8);
  vertex(x + 27, y - 8);
  vertex(x + 27, y - 18);
  vertex(x + 44, y - 18);
  vertex(x + 44, y - 7);
  vertex(x + 60, y - 7);
  vertex(x + 60, y);
  vertex(x + 75, y);
  endShape();
}

boolean isDucking() {
  return (joystickDown || keyboardDown) && jumpHeight == 0 && jumpVelocity == 0;
}

SpritePose dinoPose() {
  int frame;
  if (jumpHeight > 0) {
    frame = 0;
  } else {
    frame = int(animationTime * RUN_ANIMATION_FPS) % 2;
  }
  boolean ducking;
  if (gameOver) {
    ducking = diedDucking;
  } else {
    ducking = isDucking();
  }
  PImage sprite;
  if (gameOver) {
    if (ducking) {
      sprite = duckEnd;
    } else {
      sprite = dinoEnd;
    }
  } else {
    if (ducking) {
      sprite = duckFrames[frame];
    } else {
      sprite = dinoFrames[frame];
    }
  }
  PImage sizeReference;
  float spriteHeight;
  if (ducking) {
    sizeReference = duckFrames[0];
    spriteHeight = sizeReference.height * DINO_HEIGHT / dinoFrames[0].height;
  } else {
    sizeReference = dinoFrames[frame];
    spriteHeight = DINO_HEIGHT;
  }
  float spriteWidth = spriteHeight * sizeReference.width / sizeReference.height;
  float top = GROUND_Y - spriteHeight - jumpHeight;
  return new SpritePose(sprite, DINO_X, top, spriteWidth, spriteHeight, false);
}

class SpritePose {
  PImage sprite;
  float x, y, w, h;
  boolean mirrored;

  SpritePose(PImage image, float left, float top, float wide, float high, boolean flip) {
    sprite = image;
    x = left;
    y = top;
    w = wide;
    h = high;
    mirrored = flip;
  }

  void display() {
    pushMatrix();
    if (mirrored) {
      translate(x + w, y);
    } else {
      translate(x, y);
    }
    if (mirrored) {
      scale(-1, 1);
    }
    image(sprite, 0, 0, w, h);
    popMatrix();
  }

  boolean opaqueAt(float px, float py) {
    float u = (px - x) / w;
    if (mirrored) {
      u = 1 - u;
    }
    int sx = constrain(int(u * sprite.width), 0, sprite.width - 1);
    int sy = constrain(int((py - y) / h * sprite.height), 0, sprite.height - 1);
    return ((sprite.pixels[sy * sprite.width + sx] >>> 24) & 255) > 127;
  }

  boolean touches(SpritePose other) {
    float left = max(x, other.x);
    float right = min(x + w, other.x + other.w);
    float top = max(y, other.y);
    float bottom = min(y + h, other.y + other.h);
    if (left >= right || top >= bottom) {
      return false;
    }
    sprite.loadPixels();
    other.sprite.loadPixels();
    // checking for transparent pixels
    for (float py = top + 0.5; py < bottom; py++) {
      for (float px = left + 0.5; px < right; px++) {
        if (opaqueAt(px, py) && other.opaqueAt(px, py)) {
          return true;
        }
      }
    }
    return false;
  }
}

void checkCollisions() {
  if (shieldTimeLeft() > 0) {
    return;
  }
  SpritePose dino = dinoPose();
  for (Obstacle obstacle : obstacles) {
    if (dino.touches(obstacle.pose())) {
      diedDucking = isDucking();
      gameOver = true;
      return;
    }
  }
}

void restartGame() {
  shieldRemainingMs = 0;
  cooldownRemainingMs = 0;
  shieldUpdatedAt = millis();
  keyboardShieldStartedAt = -1;
  shieldResetPending = myPort != null;
  if (myPort != null) {
    myPort.write('R');
  }
  gameOver = false;
  diedDucking = false;
  obstacles.clear();
  distance = 0;
  score = 0;
  elapsedRunTime = 0;
  animationTime = 0;
  jumpHeight = 0;
  jumpVelocity = 0;
  currentSpeed = RUN_SPEED;
  nextObstacleDistance = 250;
  lastFrameTime = millis();
  instructionsStartedAt = millis();
}

float shieldTimeLeft() {
  float keyboardRemaining;
  if (keyboardShieldStartedAt < 0) {
    keyboardRemaining = 0;
  } else {
    keyboardRemaining = max(0, SHIELD_DURATION_MS - (millis() - keyboardShieldStartedAt));
  }
  return max(keyboardRemaining, max(0, shieldRemainingMs - (millis() - shieldUpdatedAt)));
}

float cooldownTimeLeft() {
  int elapsed;
  if (keyboardShieldStartedAt < 0) {
    elapsed = 0;
  } else {
    elapsed = millis() - keyboardShieldStartedAt;
  }
  float keyboardRemaining;
  if (keyboardShieldStartedAt < 0 || elapsed < SHIELD_DURATION_MS) {
    keyboardRemaining = 0;
  } else {
    keyboardRemaining = max(0, SHIELD_DURATION_MS + SHIELD_COOLDOWN_MS - elapsed);
  }
  return max(keyboardRemaining, max(0, cooldownRemainingMs - (millis() - shieldUpdatedAt)));
}

void activateKeyboardShield() {
  if (gameOver || shieldTimeLeft() > 0 || cooldownTimeLeft() > 0) {
    return;
  }
  keyboardShieldStartedAt = millis();
  if (myPort != null && lastSerialTime >= 0 && millis() - lastSerialTime < 1500) {
    myPort.write('S');
  }
}

void jump() {
  if (!gameOver && jumpHeight == 0 && jumpVelocity == 0) {
    jumpVelocity = JUMP_SPEED;
  }
}

void keyPressed() {
  if (gameOver && key == ' ' && !keyboardUp) {
    restartGame();
    keyboardUp = true;
    return;
  }
  if (key == CODED && keyCode == DOWN) keyboardDown = true;
  if (key == CODED && keyCode == LEFT) keyboardLeft = true;
  if (key == CODED && keyCode == RIGHT) keyboardRight = true;
  if ((key == 's' || key == 'S') && !keyboardShield) {
    keyboardShield = true;
    activateKeyboardShield();
  }
  if ((key == ' ' || (key == CODED && keyCode == UP)) && !keyboardUp) {
    keyboardUp = true;
    jump();
  }
}

void keyReleased() {
  if (key == CODED && keyCode == DOWN) keyboardDown = false;
  if (key == CODED && keyCode == LEFT) keyboardLeft = false;
  if (key == CODED && keyCode == RIGHT) keyboardRight = false;
  if (key == 's' || key == 'S') keyboardShield = false;
  if (key == ' ' || (key == CODED && keyCode == UP)) keyboardUp = false;
}
