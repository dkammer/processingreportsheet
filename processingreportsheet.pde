import java.util.*;
import processing.pdf.*;

PGraphicsPDF pdf = null;
int appWidth = 595; // A4
int appHeight = (int) (appWidth * sqrt(2));
float printDPI = 300; 
float screenDPI = 144;
float scaleFactor = printDPI / screenDPI;
int hiResWidth = (int)(appWidth * scaleFactor);
int hiResHeight = (int)(appHeight * scaleFactor);

PFont mediumFont; 
PFont lightFont; 
PFont lightCondensedFont;
PFont lightCondensedBoldFont;
PFont lightLargeFont;
PFont smallFont; 
PFont largeFont;
PFont sectionFont;

Table students;
Map<String, Map<Integer, Task>> results = new HashMap<String, Map<Integer, Task>>();
Map<Integer, AverageTask> average = new HashMap<Integer, AverageTask>();

void settings() { 
  if(singlePage) {
    size(appWidth, appHeight);
  } else {
    size(hiResWidth, hiResHeight, PDF, resultFile + ".pdf");
  }  
}

void setup() {  
  noLoop();
  scale(scaleFactor);
  
  sectionFont = createFont("data/RobotoCondensed-Regular.ttf", 9);
  largeFont = createFont("data/Roboto-Medium.ttf", 60);
  mediumFont = createFont("data/Roboto-Medium.ttf", 18);
  smallFont = createFont("data/RobotoCondensed-Light.ttf", 7);
  lightFont = createFont("data/Roboto-Light.ttf", 9);
  lightCondensedFont = createFont("data/RobotoCondensed-Light.ttf", 7);
  lightCondensedBoldFont = createFont("data/RobotoCondensed-Regular.ttf", 7);
  lightLargeFont = createFont("data/Roboto-Light.ttf", 24);
  students = loadTable("data/" + resultFile + ".csv", "header");
  String[] headers = students.getColumnTitles();   

  // process individual tasks of students
  for (TableRow row : students.rows()) {
    Map<Integer, Task> tasks = new HashMap<Integer, Task>();
    results.put(row.getString("Id"), tasks);
    for (String header : headers) {
      if (header.contains("_")) {
        String[] tokens = header.split("_");
        int nr = Integer.parseInt(tokens[0]);
        Task t = tasks.get(nr);
        if (t == null) {
          t = new Task(nr);
          tasks.put(nr, t);
        }
        if (header.contains("Beschreibung") || header.contains("Description")) {          
          t.description = row.getString(header);
        }
        if (header.contains("MaxPunkte") || header.contains("MaxPoints")) {          
          t.maxPoints = Float.parseFloat(row.getString(header));
        }
        if (header.contains("Punkte") || header.contains("Points")) {          
          try {
            t.points = Float.parseFloat(row.getString(header));
          } catch(Exception e) {
            t.points = 0;
          }
        }
      }
    }
  }

  // calculate averages
  for (Map.Entry<String, Map<Integer, Task>> entry : results.entrySet()) {
    Map<Integer, Task> value = entry.getValue();
    for (Map.Entry<Integer, Task> taskentry : value.entrySet()) {        
      Integer taskNumber = taskentry.getKey();
      Task task = taskentry.getValue();
      AverageTask avg = average.get(taskNumber);
      if (avg == null) {
        avg = new AverageTask(taskNumber);
        average.put(taskNumber, avg);
      }
      avg.sum += task.points;
      avg.maxPoints = task.maxPoints;
      if (avg.maximum < task.points && task.points <= avg.maxPoints) avg.maximum = task.points;
      if (avg.minimum > task.points) avg.minimum = task.points;
      avg.count++;
    }
  }
}

void draw() {
  int iterationCount = 0;
  String title = resultFile.replace("-", " ");
  for (Map.Entry<String, Map<Integer, Task>> entry : results.entrySet()) {    
    String key = entry.getKey();
    Map<Integer, Task> value = entry.getValue();
    if(singlePage) {
      pdf = (PGraphicsPDF) createGraphics(hiResWidth, hiResHeight, PDF, "exports/" + key + "-"+ resultFile + ".pdf");
      pdf.beginDraw();
      
    } else if (pdf == null) {
      pdf = (PGraphicsPDF) g;
      pdf.beginDraw();
    }   

    // print header and total points
    int yOffset = marginTop;
    float xStart = marginLeft + leftColumn + spacing;
    pdf.textAlign(LEFT);
    pdf.fill(textColor);
    pdf.background(255, 255, 255);
    pdf.textFont(mediumFont);
    pdf.text(key, marginLeft, yOffset);
    pdf.textFont(sectionFont);
    pdf.text(title, xStart, yOffset);
    yOffset += headBuffer;      
    pdf.textFont(largeFont);
    float totalPoints = getTotalPoints(value);
    String pointsString = convertPoints(totalPoints);      
    pdf.text(pointsString, xStart, yOffset);
    float xOffset = pdf.textWidth(pointsString);
    pdf.textFont(lightLargeFont);
    pdf.text("/ " + convertPoints(getTotalMaxPoints()), xStart + xOffset + 10, yOffset);
    pdf.textFont(sectionFont);
    pdf.text(new Language().get("totalpoints"), xStart, yOffset + 20);
    pdf.textFont(lightLargeFont);
    xStart = xStart + columnWidth * 2;
    pdf.text(round(getTotalAveragePoints()), xStart, yOffset);
    pdf.textFont(sectionFont);
    pdf.text(new Language().get("averagepoints"), xStart, yOffset + 20);

    // print graph
    float barWidth = columnWidth * 2 + 100;
    float avgPoints = map(getTotalAveragePoints(), 0, getTotalMaxPoints(), 0, barWidth);
    float myPoints = map(totalPoints, 0, getTotalMaxPoints(), 0, barWidth);
    xStart = marginLeft + leftColumn + spacing;
    pdf.noStroke();
    pdf.fill(lightGray);
    pdf.rect(xStart, yOffset + 45, barWidth, 5);
    pdf.fill(darkGray);
    pdf.rect(xStart, yOffset + 45, avgPoints, 5);
    pdf.fill(cyan);
    pdf.rect(xStart + myPoints - 1, yOffset + 35, 1, 25);

    // print tasks      
    yOffset += tasksBuffer;
    pdf.fill(textColor);
    pdf.textFont(sectionFont);
    pdf.text(new Language().get("tasks"), marginLeft + leftColumn + spacing, yOffset);
    yOffset += 30;
    int tasksPrinted = 0;
    int currentColumn = 0;
    List<PVector> polygon = new ArrayList<PVector>();
    List<PVector> avgPolygon = new ArrayList<PVector>();
    for (Map.Entry<Integer, Task> taskentry : value.entrySet()) {        
      Integer taskNumber = taskentry.getKey();
      Task task = taskentry.getValue();
      AverageTask avg = average.get(taskNumber);
      xStart = marginLeft + leftColumn + (currentColumn * columnWidth);

      pdf.textFont(mediumFont);
      pdf.textAlign(RIGHT);
      pdf.text(taskNumber, xStart, yOffset);
      pdf.textAlign(LEFT);
      pdf.textFont(lightFont);
      xStart += spacing;
      breakText(task.description, xStart, yOffset, 10, 80);

      // draw graphics
      float barHeight = 9;
      float width = 100;
      pdf.noStroke();

      // points        
      float m = map(task.points, 0, task.maxPoints, 0, width);
      pdf.fill(lightGray);
      pdf.rect(xStart, yOffset + 13, width, barHeight);
      pdf.fill(cyan);
      pdf.rect(xStart, yOffset + 13, m, barHeight);

      // max
      pdf.fill(darkGray);
      pdf.rect(xStart, yOffset + 24, width, barHeight);

      // best
      m = map(avg.maximum, 0, task.maxPoints, 0, width);
      pdf.fill(lightGray);
      pdf.rect(xStart, yOffset + 33, width, barHeight);
      pdf.fill(darkGray);
      pdf.rect(xStart, yOffset + 33, m, barHeight); 

      // average
      m = map(avg.getAveragePoints(), 0, task.maxPoints, 0, width);
      pdf.fill(lightGray);
      pdf.rect(xStart, yOffset + 42, width, barHeight);
      pdf.fill(darkGray);
      pdf.rect(xStart, yOffset + 42, m, barHeight);

      // worst
      m = map(avg.minimum, 0, task.maxPoints, 0, width);
      pdf.fill(lightGray);
      pdf.rect(xStart, yOffset + 51, width, barHeight);
      pdf.fill(darkGray);
      pdf.rect(xStart, yOffset + 51, m, barHeight);

      pdf.fill(10, 10, 10);
      pdf.textFont(lightCondensedBoldFont);
      if (task.points > 0) pdf.fill(255, 255, 255);
      pdf.text(new Language().getUpper("points"), xStart + 2, yOffset + 20);       

      pdf.textFont(lightCondensedFont);
      pdf.fill(textColor);
      pdf.text(new Language().getUpper("max"), xStart + 2, yOffset + 31);
      pdf.text(new Language().getUpper("best"), xStart + 2, yOffset + 40);
      pdf.text(new Language().getUpper("avg"), xStart + 2, yOffset + 49);
      pdf.text(new Language().getUpper("min"), xStart + 2, yOffset + 58);

      // print points
      pdf.textAlign(RIGHT);
      pdf.textFont(lightCondensedBoldFont);
      if (task.points >= task.maxPoints) pdf.fill(255, 255, 255);
      pdf.text(convertPoints(task.points), xStart + width - 2, yOffset + 20);
      pdf.textFont(lightCondensedFont);
      pdf.fill(textColor);
      pdf.text(convertPoints(task.maxPoints), xStart + width - 2, yOffset + 31);        
      pdf.text(convertPoints(avg.maximum), xStart + width - 2, yOffset + 40);
      pdf.text(convertPoints(avg.getAveragePoints()), xStart + width - 2, yOffset + 49);
      pdf.text(convertPoints(avg.minimum), xStart + width - 2, yOffset + 58);

      // print star graph
      int numTasks = average.size();
      int lineWidth = 50;
      int originX = marginLeft + leftColumn + columnWidth * 2 + spacing + lineWidth;
      int originY = marginTop + lineWidth - 6;      
      
      pdf.stroke(50,50,50);      
      int i = task.number - 1;
      float linePoints = map(task.points, 0, task.maxPoints, 0, lineWidth);
      float lineAverage = map(avg.getAveragePoints(), 0, task.maxPoints, 0, lineWidth);
      
      pdf.strokeWeight(0.5);
      
      // 1. Calculate the angle manually
      float angle = radians(360.0/numTasks * i) - radians(90);
      
      // 2. Draw the visual line using matrix (this part is fine for visual output)
      pdf.pushMatrix(); 
      pdf.translate(originX, originY);
      pdf.rotate(angle);
      pdf.line(0, 0, lineWidth, 0);
      pdf.popMatrix();
      
      // 3. Calculate the Polygon vectors using pure Math (Sin/Cos)
      // This decouples your data from the drawing state
      float x, y;
      
      // For the task points
      x = originX + cos(angle) * linePoints;
      y = originY + sin(angle) * linePoints;
      polygon.add(new PVector(x, y));
      
      // For the average points
      x = originX + cos(angle) * lineAverage;
      y = originY + sin(angle) * lineAverage;
      avgPolygon.add(new PVector(x, y));

      // finish task printout
      tasksPrinted++;
      currentColumn++;
      if (tasksPrinted % 3 == 0) {
        yOffset += columnHeight;
        currentColumn = 0;
      }
    }

    // print polygons
    pdf.noStroke();
    pdf.strokeWeight(0.75);
    pdf.fill(darkGray, 50);
    pdf.beginShape();
    for (int i = 0; i < avgPolygon.size(); i++) {
      pdf.vertex(avgPolygon.get(i).x, avgPolygon.get(i).y);
    }
    pdf.endShape(CLOSE);
    pdf.stroke(darkGray);
    for (int i = 0; i < avgPolygon.size() - 1; i++) {
      pdf.line(avgPolygon.get(i).x, avgPolygon.get(i).y, avgPolygon.get(i+1).x, avgPolygon.get(i+1).y);
    }
    pdf.line(avgPolygon.get(0).x, avgPolygon.get(0).y, avgPolygon.get(polygon.size()-1).x, avgPolygon.get(polygon.size()-1).y);

    pdf.noStroke();
    pdf.fill(cyan, 50);
    pdf.beginShape();
    for (int i = 0; i < polygon.size(); i++) {
      pdf.vertex(polygon.get(i).x, polygon.get(i).y);
    }
    pdf.endShape(CLOSE);
    pdf.stroke(cyan);
    for (int i = 0; i < polygon.size() - 1; i++) {
      pdf.line(polygon.get(i).x, polygon.get(i).y, polygon.get(i+1).x, polygon.get(i+1).y);
    }
    pdf.line(polygon.get(0).x, polygon.get(0).y, polygon.get(polygon.size()-1).x, polygon.get(polygon.size()-1).y);

    // print version and date
    pdf.fill(textColor);
    pdf.textFont(smallFont);
    pdf.textAlign(LEFT);
    pdf.translate(marginLeft + 7, 800);
    pdf.rotate(-1 * HALF_PI);
    pdf.text("Report Sheet " + versionString + "." + nf(day(), 2) + "." + nf(month(), 2) + "." + year(), 0, 0);
    pdf.text(new Language().get("disclaimer"), 0, 10);
    
    // finish page
    if (iterationCount++ < results.size() - 1 && !singlePage) {
      pdf.nextPage();
    }
    if (singlePage) {
      pdf.dispose();
      pdf.endDraw();
    }
  }

  // cleanup and exit
  if (!singlePage) {
    pdf.dispose();
    pdf.endDraw();
  }

  exit();
}
