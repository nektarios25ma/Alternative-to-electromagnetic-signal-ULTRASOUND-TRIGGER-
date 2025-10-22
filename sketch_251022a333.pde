// HCSR04_Visualizer.pde — Processing 4 (Java mode)
// Κάθετος αισθητήρας, διαμήκες κύμα, panel τύπων, μεγάλη φόρμουλα
// + ΖΩΝΤΑΝΟΣ υπολογισμός x από duration t (ToF) κάτω από τη φόρμουλα.
// Δουλεύει είτε λαμβάνει distance (cm) είτε ToF (μs) από το Arduino.

import processing.serial.*;
import java.util.*;

// ---------- Window ----------
int initialW = 1500, initialH = 860;
void settings() { size(initialW, initialH); }

// ---------- App state ----------
enum AppState { PORT_SELECT, RUN }
AppState appState = AppState.PORT_SELECT;

Serial myPort;
String[] ports = new String[0];
int hoverIndex = -1;
boolean serialOK = false;
String statusMsg = "Διάλεξε θύρα (1–9/κλικ). [A]uto, [R]efresh, [S] Simulation. Κλείσε το Serial Monitor.";

// ---------- Physics / State ----------
float tempC = 20.0;          // θερμοκρασία
float v_cm_us;               // ταχύτητα ήχου σε cm/μs
float measuredCm = 50;       // απόσταση για τη σκηνή
float targetHeightCm = 80;   // ύψος στόχου
float tof_us = 0;            // τρέχον ToF που χρησιμοποιεί η απεικόνιση (μs)
float pingStart_ms = -1;     // έναρξη animation

// — νέα: καταγραφή από Serial (αν έρθει ToF ή distance)
float lastToF_us = Float.NaN;      // άμεσα από Arduino (αν σταλεί)
float lastDist_cm = Float.NaN;     // άμεσα από Arduino (αν σταλεί)

// ---------- Stability (για glow) ----------
ArrayList<Float> hist = new ArrayList<Float>();
int histMax = 20; boolean isStable = false; float stableThreshCm = 0.5;

void pushHistory(float cm){
  hist.add(cm); if (hist.size() > histMax) hist.remove(0);
  if (hist.size() < 8) { isStable = false; return; }
  float mn = 1e9, mx = -1e9; for (float v : hist){ if (v<mn) mn=v; if (v>mx) mx=v; }
  isStable = (mx - mn) < stableThreshCm;
}

// ---------- Layout / Colors ----------
float pxPerCm = 3.0;
int marginL = 90, marginR = 560, marginTop = 60, marginBottom = 40;

int colBg        = color(11,16,32);
int colAxis      = color(31,41,55);
int colTextDim   = color(148,163,184);
int colSensorBox = color(30,41,59);
int colSensorStk = color(226,232,240);
int colTx        = color(14,165,233);
int colRx        = color(34,197,94);
int colDist      = color(234,179,8);
int colTarget    = color(71,85,105);

// ---------- Helpers ----------
void computeVelocity() {
  // v (cm/μs) = (331.3 + 0.606*T) * 100 / 1e6
  v_cm_us = (331.3 + 0.606 * tempC) * 100.0 / 1e6;
}
float v_ms_value(){ return (331.3f + 0.606f * tempC); } // για m/s

void startPingDist(float cm) {
  measuredCm = constrain(cm, 3, 400);
  tof_us = 2 * measuredCm / v_cm_us;          // παράγω ToF από d
  pingStart_ms = millis();
  pushHistory(measuredCm);
}
void startPingToF(float t_us) {
  lastToF_us = max(0, t_us);
  measuredCm = (v_cm_us * lastToF_us) / 2.0;  // παράγω d από ToF
  tof_us = lastToF_us;
  pingStart_ms = millis();
  pushHistory(measuredCm);
}

// ---------- Serial ----------
void refreshPorts() {
  ports = Serial.list(); if (ports == null) ports = new String[0];
  statusMsg = (ports.length == 0)
    ? "Καμία θύρα. Σύνδεσε Arduino και πάτα [R]. [S] για Simulation."
    : "Διάλεξε θύρα με κλικ ή 1–9. [A]uto, [R]efresh, [S] Simulation. (Κλείσε το Serial Monitor στο IDE)";
}
boolean tryOpen(String portName, int baud) {
  try { if (myPort != null) { myPort.stop(); myPort = null; }
        myPort = new Serial(this, portName, baud);
        myPort.clear(); myPort.bufferUntil('\n');
        serialOK = true; statusMsg = "Συνδέθηκε στο " + portName + " @ " + baud + " baud."; return true;
  } catch (Exception e) { serialOK = false; statusMsg = "Αποτυχία σύνδεσης: " + e.getMessage(); return false; }
}
boolean autoPickAndOpen() {
  String cand = null;
  for (String p : ports) if (p.matches(".*COM\\d+.*")) { cand = p; break; }
  if (cand == null) for (String p : ports) if (p.toLowerCase().contains("usb")) { cand = p; break; }
  if (cand == null && ports.length > 0) cand = ports[0];
  if (cand == null) { statusMsg = "Δεν βρέθηκε θύρα. [R] για επανάληψη."; return false; }
  return tryOpen(cand, 9600);
}

void serialEvent(Serial p) {
  String line = p.readStringUntil('\n'); if (line == null) return;
  line = trim(line); if (line.length() == 0) return;
  if (line.toLowerCase().contains("εκτός")) return;

  String cleaned = line.replace(',', '.');
  // Προτεραιότητα: αν υπάρχει T:… (μs) → ToF, αν υπάρχει D:… (cm) → distance
  String[] mt = match(cleaned, "(?i)\\bT\\s*[:=]\\s*([0-9]+\\.?[0-9]*)");
  String[] md = match(cleaned, "(?i)\\bD\\s*[:=]\\s*([0-9]+\\.?[0-9]*)");

  if (mt != null && mt.length > 1) { // explicit ToF σε μs
    float t = float(mt[1]);
    lastToF_us = t; lastDist_cm = (v_cm_us * t) / 2.0;
    startPingToF(t);
    return;
  }
  if (md != null && md.length > 1) { // explicit distance σε cm
    float d = float(md[1]);
    lastDist_cm = d; lastToF_us = Float.NaN;
    startPingDist(d);
    return;
  }

  // Αλλιώς: πιάσε τον πρώτο αριθμό και μάντεψε μονάδα (cm ή μs)
  String[] m = match(cleaned, "[-+]?[0-9]*\\.?[0-9]+");
  if (m != null && m.length > 0) {
    float v = float(m[0]);
    // hint από τη γραμμή: αν γράφει us/μs → ToF
    boolean saysUs = cleaned.toLowerCase().contains("us") || cleaned.contains("μs");
    if (saysUs || v > 800) {    // >800 → προφανώς μs, όχι cm
      lastToF_us = v; lastDist_cm = (v_cm_us * v) / 2.0;
      startPingToF(v);
    } else {                    // αλλιώς cm
      lastDist_cm = v; lastToF_us = Float.NaN;
      startPingDist(v);
    }
  }
}

// ---------- Setup / Draw ----------
void setup() {
  surface.setTitle("HC-SR04 – Live Physics Visualizer (Processing)");
  surface.setResizable(true);
  textFont(createFont("Arial", 13));
  computeVelocity();
  refreshPorts();
  pushHistory(measuredCm);
}

void draw() {
  background(colBg);
  drawHeader();

  if (appState == AppState.PORT_SELECT) { drawPortPicker(); return; }

  int contentW = width - marginL - marginR;
  int contentH = height - marginTop - marginBottom;
  int timelineH = max(160, int(contentH * 0.33));
  int sceneH = contentH - timelineH - 10;

  float usableW = contentW - 140;
  pxPerCm = max(1.2, min(usableW / 420.0, 3.8));

  int originX = marginL + 70;
  int sceneY0 = marginTop;
  int timelineY0 = marginTop + sceneH + 10;

  drawScene(originX, sceneY0, sceneH, contentW);
  drawTimeline(originX, timelineY0, timelineH, contentW);
  drawPhysicsPanel(width - marginR + 20, marginTop, marginR - 40, contentH);
}

// ---------- Header ----------
void drawHeader() {
  fill(255); textAlign(LEFT, TOP); textSize(18);
  text("HC-SR04 — Ζωντανή οπτικοποίηση (40 kHz) • Trigger/Echo • ToF • Ύψος στόχου", 16, 12);
  textSize(14);
  String vLine = String.format("T = %.1f °C   v ≈ %.1f m/s   d = %.1f cm   ToF = %.0f μs   Mode: %s",
                tempC, v_ms_value(), measuredCm, tof_us, serialOK ? "Serial" : "Simulation");
  fill(220); text(vLine, 16, 36);

  // Creator
  String creator = "ΔΗΜΙΟΥΡΓΟΣ: ΝΕΚΤΑΡΙΟΣ ΚΟΥΡΑΚΗΣ";
  int pad = 8, tw = int(textWidth(creator)), bx = width - tw - 2*pad - 16, by = 10;
  noStroke(); fill(25, 35, 60, 180); rect(bx, by, tw + 2*pad, 28, 8);
  fill(240); textAlign(LEFT, CENTER); textSize(13); text(creator, bx + pad, by + 14);
}

// ---------- Scene (vertical sensor + longitudinal wave) ----------
void drawScene(int originX, int y0, int h, int contentW) {
  int w = contentW;
  int centerY = y0 + int(h * 0.60);
  int baselineY = centerY + 60;

  // Κάθετος αισθητήρας
  pushMatrix(); translate(originX, centerY);
  fill(colSensorBox); rect(-42, -60, 84, 120, 8);
  stroke(colSensorStk); strokeWeight(2); noFill(); rect(-42, -60, 84, 120, 8);
  noStroke(); float dia = 34;
  fill(colTx); ellipse(0, -28, dia, dia);  // TRIGGER πάνω
  fill(colRx); ellipse(0, +28, dia, dia);  // ECHO κάτω
  fill(245); textAlign(CENTER, BOTTOM); textSize(12);
  text("TRIGGER (ΠΟΜΠΟΣ)", 0, -60 - 8);
  textAlign(CENTER, TOP); text("ECHO (ΔΕΚΤΗΣ)", 0, +60 + 8);
  popMatrix();

  // baseline + vertical height axis
  stroke(colAxis); strokeWeight(1);
  line(originX - 40, baselineY, originX + w - 60, baselineY);
  int axisX = originX - 50;
  line(axisX, baselineY, axisX, baselineY - int(220 * pxPerCm));
  fill(colTextDim); textAlign(CENTER, BOTTOM);
  text("Ύψος (cm)", axisX, baselineY - int(220 * pxPerCm) - 8);
  textAlign(RIGHT, CENTER);
  for (int cm=0; cm<=200; cm+=20) {
    int y = baselineY - int(cm * pxPerCm);
    stroke(colAxis); line(axisX - 6, y, axisX + 6, y);
    noStroke(); fill(colTextDim); text(cm, axisX - 10, y);
  }

  // Στόχος
  float targetX = originX + measuredCm * pxPerCm;
  float targetHpx = targetHeightCm * pxPerCm;
  float targetTop = baselineY - targetHpx;
  noStroke(); fill(colTarget); rect(targetX - 8, targetTop, 16, max(4, targetHpx), 4);

  // Βέλος ύψους (χωρίς label)
  stroke(200); strokeWeight(2); drawDimArrowV(int(targetX + 26), int(baselineY), int(targetTop), null);

  // Απόσταση ένδειξη
  stroke(colDist); strokeWeight(2);
  line(originX + 30, centerY - 45, targetX, centerY - 45);
  noStroke(); fill(colDist);
  triangle(originX + 30, centerY - 45, originX + 36, centerY - 50, originX + 36, centerY - 40);
  triangle(targetX,     centerY - 45, targetX - 6,  centerY - 50, targetX - 6,  centerY - 40);
  fill(255); textAlign(CENTER, BOTTOM);
  text("Απόσταση: " + nf(measuredCm, 0, 1) + " cm", (originX + 30 + targetX)/2, centerY - 50);

  // Διαμήκες κύμα (μεγαλύτερο οριζόντιο πλάτος)
  if (pingStart_ms >= 0) {
    float elapsed_us = (millis() - pingStart_ms) * 1000.0;
    float travelCm = v_cm_us * elapsed_us;
    float totalCm  = measuredCm * 2.0;

    float v_cm_s = v_ms_value() * 100.0;
    float lambda_cm = v_cm_s / 40000.0; // 40 kHz
    int cyclesVisual = isStable ? 28 : 20;
    float Lcm = cyclesVisual * lambda_cm;
    float bandHalf = 26;

    boolean returning = false; float x1_cm, x2_cm;
    if (travelCm <= measuredCm) { x2_cm = travelCm; x1_cm = max(0, x2_cm - Lcm); }
    else if (travelCm <= totalCm) { returning = true; float t_ret = travelCm - measuredCm; float front_cm = measuredCm - t_ret; x2_cm = max(0, front_cm); x1_cm = max(0, x2_cm - Lcm); }
    else { x1_cm = x2_cm = 0; }

    int waveCol = returning ? colRx : colTx;
    drawLongitudinalBand(originX + 30, centerY, x1_cm, x2_cm, lambda_cm, bandHalf, waveCol, isStable ? 1.35f : 1.0f);

    float x2_px = originX + 30 + x2_cm * pxPerCm;
    float x1_px = originX + 30 + x1_cm * pxPerCm;
    glowLine(x1_px, centerY, x2_px, centerY, waveCol, isStable ? 1.8 : 0.9);
  }

  // Οριζόντια κλίμακα (κάθε 50 cm)
  stroke(colAxis); fill(colTextDim); strokeWeight(1);
  textAlign(CENTER, TOP);
  for (int cm=0; cm<=400; cm+=50) {
    float x = originX + cm * pxPerCm;
    line(x, baselineY + 6, x, baselineY + 14);
    text(cm + " cm", x, baselineY + 18);
  }
}

void drawLongitudinalBand(float originX, float centerY, float x1_cm, float x2_cm,
                          float lambda_cm, float halfHeightPx, int baseCol, float boost) {
  if (x2_cm <= x1_cm) return;
  float step_cm = lambda_cm / 10.0;
  float L = (x2_cm - x1_cm);
  for (float x_cm = x1_cm; x_cm <= x2_cm; x_cm += step_cm) {
    float x_px = originX + x_cm * pxPerCm;
    float phase = TWO_PI * (x_cm / lambda_cm);
    float dens = 0.5 + 0.5 * cos(phase);
    float u = (x_cm - x1_cm) / max(1e-6, L);
    float window = 0.5 * (1 - cos(TWO_PI * constrain(u, 0, 1)));
    float alpha = (40 + 200 * dens) * window * boost; alpha = constrain(alpha, 10, 255);
    stroke(red(baseCol), green(baseCol), blue(baseCol), alpha); strokeWeight(2);
    line(x_px, centerY - halfHeightPx, x_px, centerY + halfHeightPx);
  }
}

void glowLine(float x1, float y1, float x2, float y2, int baseCol, float intensity) {
  int passes = int(10 * intensity); passes = constrain(passes, 6, 24);
  for (int i=passes; i>=1; i--) {
    float a = map(i, passes, 1, 20, 140) * intensity;
    stroke(red(baseCol), green(baseCol), blue(baseCol), constrain(a, 10, 255));
    strokeWeight(i * 1.6); line(x1, y1, x2, y2);
  }
  stroke(red(baseCol), green(baseCol), blue(baseCol), 255);
  strokeWeight(3.6); line(x1, y1, x2, y2);
}

void drawDimArrowV(int x, int yBottom, int yTop, String label) {
  line(x, yBottom, x, yTop); line(x - 6, yBottom, x + 6, yBottom); line(x - 6, yTop, x + 6, yTop);
}

// ---------- Timeline ----------
void drawTimeline(int originX, int y0, int h, int contentW) {
  int w = contentW; noStroke(); fill(colBg); rect(originX - 70, y0, w, h);
  float tof = (lastValidToF() > 0) ? lastValidToF() : ((2 * measuredCm) / v_cm_us); // προτίμηση direct ToF
  float span_us = max(2000, tof * 1.35);
  int xStart = originX - 20, xEnd = originX - 20 + (w - 110);

  stroke(51, 65, 85); strokeWeight(1.5); line(xStart, y0 + h - 40, xEnd, y0 + h - 40);
  fill(colTextDim); textAlign(CENTER, TOP);
  float step = max(100, round(span_us/10/100)*100);
  for (float t=0; t<=span_us+1; t+=step) {
    float x = tToX(t, span_us, xStart, xEnd);
    stroke(51,65,85); line(x, y0 + h - 44, x, y0 + h - 36);
    noStroke(); text(nf(t,0,0) + " μs", x, y0 + h - 32);
  }

  noStroke(); fill(colTx);
  float t0 = tToX(0, span_us, xStart, xEnd), t1 = tToX(10, span_us, xStart, xEnd);
  rect(t0, y0 + 30, max(2, t1 - t0), 28);
  fill(203, 213, 225); textAlign(LEFT, BOTTOM); text("Trigger (10 μs)", t0, y0 + 26);

  fill(colRx);
  float e0 = tToX(0, span_us, xStart, xEnd), e1 = tToX(tof, span_us, xStart, xEnd);
  rect(e0, y0 + 90, max(2, e1 - e0), 28);
  fill(203, 213, 225); text("Echo (" + int(tof) + " μs)", e0, y0 + 86);
}
float lastValidToF(){ return !Float.isNaN(lastToF_us) ? lastToF_us : tof_us; }
float tToX(float us, float spanUs, int xStart, int xEnd){ return xStart + (us / spanUs) * (xEnd - xStart); }

// ---------- Physics panel (with big formula + live x from t) ----------
void drawPhysicsPanel(int x, int y, int w, int h) {
  noStroke(); fill(25, 35, 60, 220); rect(x, y, w, h, 12);

  fill(240); textAlign(LEFT, TOP); textSize(20); text("ΤΥΠΟΙ ΦΥΣΙΚΗΣ", x + 16, y + 12);

  float f = 40000.0, period_us = 1e6f/f, v_ms = v_ms_value(), v_cm_s = v_ms*100.0f, lambda_cm = v_cm_s/f;
  int yy = y + 54;

  textSize(22); fill(255); text("DATA: distance = " + nf(measuredCm, 0, 2) + " cm", x + 16, yy); yy += 30;

  textSize(16); fill(220);
  text("Συχνότητα: f = 40 kHz", x + 16, yy); yy += 22;
  text("Περίοδος: T = 1/f = " + nf(period_us, 0, 1) + " μs", x + 16, yy); yy += 22;
  text("Παλμός εκπομπής: 8 κύκλοι ≈ " + nf(period_us*8, 0, 0) + " μs", x + 16, yy); yy += 22;

  String vLine = "Ταχύτητα: v(T) = 331.3 + 0.606·T  [m/s]  → v ≈ " + nf(v_ms, 0, 1) + " m/s";
  drawFitText(vLine, x + 16, yy, w - 32, 20, color(255)); yy += 30;

  textSize(16); fill(220);
  text("Μήκος κύματος: λ = v / f ≈ " + nf(lambda_cm, 0, 2) + " cm", x + 16, yy); yy += 22;
  text("Χρόνος πτήσης: ToF = 2·x / v", x + 16, yy); yy += 22;
  text("Απόσταση: x = v·ToF / 2", x + 16, yy); yy += 26;

  float tof_calc = 2 * measuredCm / v_cm_us;
  textSize(16); fill(200);
  text("Με τιμές:", x + 16, yy); yy += 22;
  text("x = " + nf(measuredCm, 0, 2) + " cm,  T = " + nf(tempC, 0, 1) + " °C → v ≈ " + nf(v_ms, 0, 1) + " m/s", x + 30, yy); yy += 22;
  text("ToF ≈ 2·" + nf(measuredCm, 0, 2) + " / " + nf(v_cm_us, 0, 5) + " ≈ " + int(tof_calc) + " μs", x + 30, yy); yy += 22;
  text("λ ≈ " + nf(lambda_cm, 0, 2) + " cm  (στα " + nf(tempC, 0, 1) + " °C)", x + 30, yy);

  // --- Μεγάλη φόρμουλα + ΖΩΝΤΑΝΟΣ υπολογισμός από duration t ---
  String bigF = "x = v · ToF / 2";
  int pad = 14, areaH = 100;             // ↑ αυξήθηκε για δεύτερη γραμμή
  int by = y + h - areaH - pad;
  noStroke(); fill(17, 24, 39, 220); rect(x + pad, by, w - 2*pad, areaH, 10);
  drawFitTextShadow(bigF, x + pad + 10, by + 12, w - 2*pad - 20, 34, color(255));

  // προτίμηση σε άμεσο ToF από Serial, αλλιώς υπολογισμένο
  // Ζωντανός υπολογισμός από t: x = v·t/2 (v σε cm/μs)
float t_us = lastValidToF();
float x_cm_from_t = (v_cm_us * t_us) / 2.0;
String live = "t = " + int(t_us) + " μs   ⇒   x = v·t/2 = " 
              + nf(v_cm_us, 0, 5) + " cm/μs · " + int(t_us) + " / 2 ≈ " 
              + nf(x_cm_from_t, 0, 2) + " cm";
drawFitText(live, x + pad + 14, by + 56, w - 2*pad - 28, 20, color(255));

}

// ----- text helpers -----
void drawFitText(String s, int x, int y, int maxW, float targetSize, int col) {
  float fs = targetSize; textSize(fs); while (textWidth(s) > maxW && fs > 11) { fs -= 1; textSize(fs); }
  fill(col); textAlign(LEFT, TOP); text(s, x, y);
}
void drawFitTextShadow(String s, int x, int y, int maxW, float targetSize, int col) {
  float fs = targetSize; textSize(fs); while (textWidth(s) > maxW && fs > 12) { fs -= 1; textSize(fs); }
  fill(0,0,0,140); textAlign(LEFT, TOP); text(s, x+2, y+2);
  fill(col); text(s, x, y);
}

// ---------- Port picker ----------
void drawPortPicker() {
  fill(255); textAlign(LEFT, TOP); textSize(18);
  text("Επιλογή Θύρας Serial για Arduino", 20, 18);
  textSize(13); fill(200);
  text("• Κλείσε το Serial Monitor του Arduino IDE\n• Βρες τη θύρα (π.χ. COM16)\n• Πάτα 1–9 ή κάνε κλικ\n• [A]uto, [R]efresh, [S] Simulation", 20, 50);

  float y = 120, lineH = 28; noStroke();
  for (int i=0; i<ports.length && i<9; i++) {
    boolean hover = (i == hoverIndex);
    fill(hover ? color(35, 50, 90) : color(25, 35, 60));
    rect(20, y + i*lineH, width - 40, lineH - 4, 6);
    fill(230); text((i+1) + ") " + ports[i], 28, y + i*lineH + 6);
  }
  float yBtn = y + max(9, ports.length) * lineH + 10;
  fill(230); text("[A] Auto   [R] Refresh   [S] Simulation", 20, yBtn);
  fill(180); text(statusMsg, 20, yBtn + 30);
}

// ---------- Events ----------
void mouseMoved() {
  if (appState != AppState.PORT_SELECT) return;
  hoverIndex = -1; float y = 120, lineH = 28;
  for (int i=0; i<ports.length && i<9; i++) {
    float yy = y + i*lineH;
    if (mouseX >= 20 && mouseX <= width-20 && mouseY >= yy && mouseY <= yy + lineH - 4) { hoverIndex = i; break; }
  }
}
void mousePressed() {
  if (appState != AppState.PORT_SELECT) return;
  if (hoverIndex >= 0 && hoverIndex < ports.length) { if (tryOpen(ports[hoverIndex], 9600)) { appState = AppState.RUN; startPingDist(measuredCm); } }
}
void keyPressed() {
  if (appState == AppState.PORT_SELECT) {
    if (key >= '1' && key <= '9') { int idx = (key - '1'); if (idx >= 0 && idx < ports.length) { if (tryOpen(ports[idx], 9600)) { appState = AppState.RUN; startPingDist(measuredCm); } } }
    else if (key == 'a' || key == 'A') { if (autoPickAndOpen()) { appState = AppState.RUN; startPingDist(measuredCm); } }
    else if (key == 'r' || key == 'R') { refreshPorts(); }
    else if (key == 's' || key == 'S') { serialOK = false; appState = AppState.RUN; statusMsg = "Simulation mode."; startPingDist(measuredCm); }
    return;
  }
  // RUN
  if (!serialOK) { if (keyCode == LEFT)  startPingDist(max(3, measuredCm - 1));
                   if (keyCode == RIGHT) startPingDist(min(400, measuredCm + 1)); }
  if (keyCode == java.awt.event.KeyEvent.VK_PAGE_UP)   { tempC += 0.5; computeVelocity(); startPingDist(measuredCm); }
  if (keyCode == java.awt.event.KeyEvent.VK_PAGE_DOWN) { tempC -= 0.5; computeVelocity(); startPingDist(measuredCm); }
  if (key == 'w' || key == 'W') { targetHeightCm = min(200, targetHeightCm + 1); }
  if (key == 's' || key == 'S') { targetHeightCm = max(3,   targetHeightCm - 1); }
  if (key == '[') { surface.setSize(max(1100, int(width*0.9)), max(650, int(height*0.9))); }
  if (key == ']') { surface.setSize(int(width*1.1), int(height*1.1)); }
  if (key == ESC) { key = 0; appState = AppState.PORT_SELECT; refreshPorts();
    if (myPort != null) { try { myPort.stop(); } catch(Exception e){}; myPort = null; } serialOK = false; }
  if (key == 'r' || key == 'R') { appState = AppState.PORT_SELECT; refreshPorts();
    if (myPort != null) { try { myPort.stop(); } catch(Exception e){}; myPort = null; } serialOK = false; }
}
