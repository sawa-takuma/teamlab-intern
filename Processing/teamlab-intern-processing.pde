// Trace of Choice - Full Sketch with BLUE / GREEN / ICE
// Processing 4.x

import processing.serial.*;
import java.util.ArrayList;

Serial myPort;

// ====== 状態管理 ======
String mode = "NONE";
String pendingMode = "";
boolean pendingModeChange = false;

String lastRaw = "";
int lastReceivedAt = 0;

boolean inTransition = false;
float transitionStart = 0;
float transitionDur = 0.6;

// ====== レイヤー ======
PGraphics mainLayer, trailLayer, glowLayer;

// ====== パーティクル ======
ArrayList<BaseParticle> particles;
ArrayList<Branch> branches;

int maxParticles = 800;
float timeStart;

// =========================================================
// SETUP
// =========================================================
void setup() {
  size(1280, 720, P2D);
  frameRate(60);

  println("Serial ports: " + java.util.Arrays.toString(Serial.list()));

  try {
    myPort = new Serial(this, "COM4", 9600);
    myPort.bufferUntil('\n');
    println("Opened COM4");
  } catch (Exception e) {
    println("Serial open failed: " + e.getMessage());
  }

  mainLayer = createGraphics(width, height, P2D);
  trailLayer = createGraphics(width, height, P2D);
  glowLayer = createGraphics(width, height, P2D);

  particles = new ArrayList<BaseParticle>();
  branches = new ArrayList<Branch>();

  timeStart = millis()/1000.0;

  colorMode(HSB, 360, 100, 100, 100);
}

// =========================================================
// DRAW LOOP
// =========================================================
void draw() {
  float t = millis()/1000.0 - timeStart;

  // ====== モード切替 ======
  if (pendingModeChange) {
    pendingModeChange = false;
    mode = pendingMode;

    inTransition = true;
    transitionStart = millis()/1000.0;

    particles.clear();
    branches.clear();

    if (mode.equals("BLUE")) {
      maxParticles = 300;

      for (int i=0;i<250;i++)
        particles.add(new UnderwaterParticle(new PVector(random(width), random(height))));

      for (int i=0;i<40;i++)
        particles.add(new BubbleParticle(new PVector(random(width), random(height))));
    }
    else if (mode.equals("ICE")) {
      maxParticles = 1000;

      for (int i=0;i<1000;i++)
        particles.add(new SnowParticle(new PVector(random(width), random(height))));
    }
    else if (mode.equals("GREEN")) {
      maxParticles = 400;
      branches.add(new Branch(new PVector(width*0.5, height), -PI/2, 0));
    }
  }

  background(6, 6, 6);

  // ====== UPDATE ======
  for (int i = particles.size()-1; i >= 0; i--) {
    BaseParticle p = particles.get(i);
    p.update();
    if (p.dead) particles.remove(i);
  }

  // ====== BLUE 泡補充 ======
  if (mode.equals("BLUE")) {
    int bubbleCount = 0;
    for (BaseParticle bp : particles) {
      if (bp instanceof BubbleParticle) bubbleCount++;
    }
    int target = 40;
    int toAdd = target - bubbleCount;
    for (int i = 0; i < toAdd; i++) {
      particles.add(new BubbleParticle(new PVector(random(width), height + random(20, 80))));
    }
  }

  // ====== ICE 雪補充 ======
  if (mode.equals("ICE")) {
    while (particles.size() < 1000) {
      particles.add(new SnowParticle(new PVector(random(width), random(height))));
    }
  }

  // GREEN
  for (int i = branches.size()-1; i >= 0; i--) {
    Branch b = branches.get(i);
    b.update();
    if (b.finished) branches.remove(i);
  }

  // ====== MAIN LAYER ======
  mainLayer.beginDraw();
  mainLayer.clear();
  mainLayer.noStroke();

  if (mode.equals("NONE")) {
    drawIdle(mainLayer);
  } else {
    float trans = inTransition ? constrain((millis()/1000.0 - transitionStart)/transitionDur, 0, 1) : 1;

    if (mode.equals("BLUE")) drawBlueBackground(mainLayer, t, trans);
    if (mode.equals("GREEN")) drawModeBackground(mainLayer, "GREEN", trans);
    if (mode.equals("ICE")) drawModeBackground(mainLayer, "ICE", trans);

    for (BaseParticle bp : particles) bp.draw(mainLayer);
    for (Branch br : branches) br.draw(mainLayer);

    if (trans >= 1) inTransition = false;
  }

  mainLayer.endDraw();

  // ====== TRAIL ======
  trailLayer.beginDraw();
  trailLayer.noStroke();
  trailLayer.fill(0, 0, 0, 6);
  trailLayer.rect(0,0,width,height);
  for (BaseParticle bp : particles) bp.drawTrail(trailLayer);
  trailLayer.endDraw();

  // ====== GLOW ======
  glowLayer.beginDraw();
  glowLayer.clear();
  glowLayer.blendMode(ADD);
  for (BaseParticle bp : particles) bp.drawGlow(glowLayer);
  glowLayer.endDraw();

  // ====== COMPOSITE ======
  image(trailLayer, 0, 0);
  image(mainLayer, 0, 0);
  blendMode(ADD);
  image(glowLayer, 0, 0);
  blendMode(BLEND);

  // ====== HUD ======
  fill(0, 0, 100, 90);
  text("Mode: " + mode, 12, 12);
  text("Last raw: " + lastRaw, 12, 32);

  if (myPort != null && myPort.available() > 0) {
    String raw = myPort.readStringUntil('\n');
    if (raw != null) handleRaw(raw.trim());
  }
}

// =========================================================
// IDLE SCREEN
// =========================================================
void drawIdle(PGraphics pg) {
  pg.pushStyle();
  pg.fill(210, 20, 10);
  pg.rect(0,0,width,height);
  pg.fill(200);
  pg.textAlign(CENTER, CENTER);
  pg.textSize(28);
  pg.text("タグをかざしてください", width/2, height/2);
  pg.popStyle();
}

// =========================================================
// BLUE MODE – Deep Ocean（光の筋なし）
// =========================================================
void drawBlueBackground(PGraphics pg, float t, float intensity) {
  pg.pushStyle();
  pg.colorMode(HSB, 360, 100, 100, 100);

  // 深海グラデーション
  for (int y = 0; y < height; y++) {
    float d = map(y, 0, height, 0, 1);
    float hue = 200;
    float sat = 65 - d * 25;
    float bri = 100 - d * 70;
    pg.stroke(hue, sat, bri, 100);
    pg.line(0, y, width, y);
  }

  pg.popStyle();
}

// =========================================================
// GREEN / ICE BACKGROUND
// =========================================================
void drawModeBackground(PGraphics pg, String m, float intensity) {
  pg.pushStyle();
  pg.noStroke();

  if (m.equals("GREEN")) {
    for (int i=0;i<6;i++) {
      float a = map(i,0,5,6,50) * intensity;
      pg.fill(120, 50, 40 + i*6, a);
      pg.rect(0, i*height/6, width, height/6);
    }
  }

  if (m.equals("ICE")) {
    for (int y=0; y<height; y++) {
      float d = map(y, 0, height, 0, 1);
      float r = lerp(30, 5, d);
      float g = lerp(60, 20, d);
      float b = lerp(120, 40, d);
      float a = 100 * intensity;
      pg.fill(r, g, b, a);
      pg.rect(0, y, width, 1);
    }
  }

  pg.popStyle();
}

// =========================================================
// SERIAL
// =========================================================
void serialEvent(Serial p) {
  String raw = p.readStringUntil('\n');
  if (raw != null) handleRaw(raw.trim());
}

void handleRaw(String raw) {
  lastRaw = raw;
  lastReceivedAt = millis();

  if (raw.startsWith("MODE:")) {
    pendingMode = raw.substring(5).toUpperCase();
    pendingModeChange = true;
    return;
  }

  if (raw.equalsIgnoreCase("BLUE") ||
      raw.equalsIgnoreCase("ICE") ||
      raw.equalsIgnoreCase("GREEN")) {
    pendingMode = raw.toUpperCase();
    pendingModeChange = true;
  }
}

// =========================================================
// BASE PARTICLE
// =========================================================
abstract class BaseParticle {
  PVector pos, vel, acc;
  float life, maxLife, size;
  boolean dead = false;

  BaseParticle(PVector p) {
    pos = p.copy();
    vel = new PVector();
    acc = new PVector();
    life = 0;
    maxLife = random(2, 6);
    size = random(2, 8);
  }

  void applyForce(PVector f) { acc.add(f); }

  void update() {
    vel.add(acc);
    pos.add(vel);
    acc.mult(0);
    life += 1.0/60.0;
    if (life > maxLife) dead = true;
  }

  abstract void draw(PGraphics pg);
  void drawTrail(PGraphics pg) {}
  void drawGlow(PGraphics pg) {}
}

// =========================================================
// BLUE PARTICLE – Underwater floating dust
// =========================================================
class UnderwaterParticle extends BaseParticle {
  float hue;

  UnderwaterParticle(PVector p) {
    super(p);
    vel = PVector.random2D().mult(random(0.1, 0.4));
    maxLife = random(4.0, 10.0);
    size = random(2, 6);
    hue = random(180, 220);
  }

  void update() {
    float a = noise(pos.x*0.002, pos.y*0.002, millis()*0.0003)*TWO_PI*2;
    applyForce(new PVector(cos(a), sin(a)).mult(0.05));
    vel.mult(0.995);
    super.update();
  }

  void draw(PGraphics pg) {
    pg.pushStyle();
    pg.colorMode(HSB, 360, 100, 100, 100);
    float alpha = map(maxLife-life, 0, maxLife, 0, 60);
    pg.noStroke();
    pg.fill(hue, 20, 100, alpha);
    pg.ellipse(pos.x, pos.y, size, size);
    pg.popStyle();
  }
}

// =========================================================
// BLUE PARTICLE – Realistic Bubbles
// =========================================================
class BubbleParticle extends BaseParticle {
  float speed;

  BubbleParticle(PVector p) {
    super(p);
    size = random(3, 8);
    speed = random(0.5, 1.5);
    maxLife = random(3.0, 7.0);
  }

  void update() {
    pos.y -= speed;
    pos.x += sin(millis()*0.002 + pos.y*0.05)*0.3;

    if (pos.y < -20) dead = true;
    super.update();
  }

  void draw(PGraphics pg) {
    pg.pushStyle();
    pg.colorMode(HSB, 360, 100, 100, 100);

    pg.noStroke();
    pg.fill(200, 20, 92, 65);
    pg.ellipse(pos.x, pos.y, size, size*0.9);

    pg.fill(200, 10, 100, 90);
    pg.ellipse(pos.x - size*0.2, pos.y - size*0.2, size*0.35, size*0.35);

    pg.popStyle();
  }
}

// =========================================================
// ICE – Snow Particle（白い丸の吹雪）
// =========================================================
class SnowParticle extends BaseParticle {

  SnowParticle(PVector p) {
    super(p);
    pos = p.copy();
    vel = new PVector(random(-1, 4), random(-0.5, 2));
    acc = new PVector();
    maxLife = random(4.0, 8.0);
    size = random(3, 8);
  }

  void update() {
    applyForce(new PVector(0.4, -0.01));  // 強風 + 上昇気流
    vel.add(acc);
    pos.add(vel);
    acc.mult(0);

    if (pos.x < -50 || pos.x > width+50 || pos.y < -50 || pos.y > height+50)
      dead = true;

    life += 1.0/60.0;
    if (life > maxLife) dead = true;
  }

  void draw(PGraphics pg) {
    pg.pushStyle();
    pg.colorMode(RGB, 255);
    pg.noStroke();
    pg.fill(255, 255, 255, 240);
    pg.ellipse(pos.x, pos.y, size, size);
    pg.popStyle();
  }
}

// =========================================================
// GREEN – Branch
// =========================================================
class Branch {
  ArrayList<PVector> nodes = new ArrayList<PVector>();
  ArrayList<Float> angles = new ArrayList<Float>();
  boolean finished = false;
  int steps = 0;

  Branch(PVector root, float angle, int depth) {
    nodes.add(root.copy());
    angles.add(angle);
  }

  void update() {
    if (steps < 200) {
      PVector last = nodes.get(nodes.size()-1);
      float a = angles.get(angles.size()-1) + random(-0.25, 0.25);
      float len = map(steps, 0, 200, 6, 1.5);
      PVector next = new PVector(last.x + cos(a)*len, last.y + sin(a)*len);
      nodes.add(next);
      angles.add(a);
      steps++;

      if (random(1) < 0.02 && nodes.size() > 6)
        branches.add(new Branch(next, a + random(-0.6, 0.6), 0));
    } else {
      finished = true;
    }
  }

  void draw(PGraphics pg) {
    pg.pushStyle();
    pg.strokeWeight(2);
    pg.colorMode(RGB, 255);
    for (int i=1;i<nodes.size();i++) {
      PVector a = nodes.get(i-1);
      PVector b = nodes.get(i);
      float t = map(i, 0, nodes.size(), 0, 1);
      pg.stroke((int)lerp(40,20,t), (int)lerp(80,40,t), (int)lerp(30,20,t), 220);
      pg.line(a.x, a.y, b.x, b.y);
    }
    pg.popStyle();
  }
}
