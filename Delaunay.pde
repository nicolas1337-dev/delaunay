/**************************************************************
 Copyright 2020  Nicolas Duval vilaincoco@gmail.com

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation; either version 2 of 
 the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
***************************************************************/

// VERSION NUMBER
String versionNumber = "v2.0";

import java.io.IOException;

// SWING
import javax.swing.*;

// GLOBAL
boolean imageLoaded = false;
String filename;
PImage inputImage;
int alphaFactor = 255;
int userAlphaFactor = 150;
boolean deleteBorder = true;
boolean outlined = false;
boolean suppresion = false;
boolean control = false;
boolean voronoi = false;

// DRAG & DROP
import java.awt.dnd.*;
import java.awt.datatransfer.*;


// POINT
class Point
{   
  Point (float pX, float pY)
  {
    x = pX;
    y = pY;
  }
  
  Point less(Point p)
  {
    Point pt = new Point(x - p.x,y - p.y);
    return pt;
  }
  
  Point plus(Point p)
  {
    Point pt = new Point(x + p.x,y + p.y);
    return pt;
  }
  
  boolean equal(Point p)
  {
    return x == p.x && y == p.y; 
  }
  
  float distanceTo(Point p)
  {
    return dist(x,y,p.x,p.y); 
  }
  
  Point middle(Point p)
  {
    Point pt = new Point((x + p.x) / 2 , (y + p.y) / 2);
    return pt;
  }
  
  float x;
  float y;
}

ArrayList pointArray = new ArrayList();

// TRIANGLE
class Triangle
{
  Triangle(int pIdx1, int pIdx2, int pIdx3)
  {
    idx1 = pIdx1;
    idx2 = pIdx2;
    idx3 = pIdx3;
    r = g = b = 0;
    count = 0;
    c = color(255,0,0,255);
    updated = true;
  }
  
  void addColor(color newColor)
  {
    r += red(newColor);
    g += green(newColor);
    b += blue(newColor);
    count++;
  }
  
  void computeColor()
  {
    if (count > 0)
    {
      r = r / count;
      g = g / count; 
      b = b / count;
    }
    c = color(r,g,b,255);
    count = 0;
  }
  
  Point getPoint(int i)
  {
    if (i == 0)
    {
      Point pt1;
      pt1 = (Point)pointArray.get(idx1);
      return pt1;
    }
    if (i == 1)
    {
      Point pt2;
      pt2 = (Point)pointArray.get(idx2);
      return pt2;
    }
    if (i == 2)
    {
      Point pt3;
      pt3 = (Point)pointArray.get(idx3);
      return pt3;
    }
    
    print("GET POINT ERROR\n");
    
    return new Point(-1,-1);
  }
  
  void windingOrder()
  {
     Point v1 = getPoint(1).less(getPoint(0));
     Point v2 = getPoint(2).less(getPoint(0));
     if (v1.x * v2.y - v1.y * v2.x > 0) // Cross product
     {
       // Swap idx2 and idx3
       int tmp = idx2;
       idx2 = idx3;
       idx3 = tmp;
     }
  }
  
  int idx1;
  int idx2;
  int idx3;
  color c;
  int r;
  int g;
  int b;
  int count;
  boolean updated;
};

ArrayList triangleArray = new ArrayList();

// CLASS QUAD
class Quad
{
  Quad(int pTriangleIdx1, int pTriangleIdx2)
  {
    triangleIdx1 = pTriangleIdx1;
    triangleIdx2 = pTriangleIdx2;
  }

  int triangleIdx1;
  int triangleIdx2;
};

ArrayList quadArray = new ArrayList();

// SETUP
void setup() 
{
  String filename = "cat.png";
  // Load image
  inputImage = loadImage(filename);
  inputImage.loadPixels();
  inputImage.resize(inputImage.width/2,inputImage.height/2);
  int imageWidth = inputImage.width;
  int imageHeight = inputImage.height;
  println(imageWidth);
  println(imageHeight);
  surface.setSize(imageWidth,imageHeight);
  
  smooth();
  inputImage.updatePixels();
  image(inputImage,0,0);
  
  // Erase all
  pointArray.clear();
  triangleArray.clear();
  quadArray.clear();
  voronoi = false;
  imageLoaded = true;

  
  // Add the four points
  Point p1 = new Point(0,0);
  Point p2 = new Point(imageWidth,0);
  Point p3 = new Point(imageWidth,imageHeight);
  Point p4 = new Point(0,imageHeight);
  pointArray.add(p1);
  pointArray.add(p2);
  pointArray.add(p3);
  pointArray.add(p4);
  
  // Add the super triangle (coordinate of the window)
  Triangle t1 = new Triangle(0,1,2);
  Triangle t2 = new Triangle(0,2,3);
  triangleArray.add(t1);
  triangleArray.add(t2);
}

// DRAW
boolean savePictureEnabled = false;
boolean openProjectEnabled = false;
boolean startRecordingEnabled = false;
boolean forceFirstRefresh = true;
void draw()
{
  if (savePictureEnabled) {savePicture(); savePictureEnabled = false;}
  if (openProjectEnabled) {loadProject(); openProjectEnabled = false;}
  if (imageLoaded && forceFirstRefresh) { refresh(true); forceFirstRefresh = false; }
}

// DRAW PIXEL
void drawPixel(PImage pImage, int pX, int pY, color pColor)
{
  pImage.pixels[pY * pImage.width + pX] = pColor;
}

// CONTAIN BORDER POINT INDEX
boolean isBorderIndex(int idx)
{
  return idx < 4;
}

// CONTAIN BORDER POINT INDEX
boolean containBorderPointIdx(Triangle t)
{
  return isBorderIndex(t.idx1) || isBorderIndex(t.idx2) || isBorderIndex(t.idx3);
}

// BOUNDING BOX
void boundingBox(Triangle t, Point minPoint, Point maxPoint)
{
  minPoint.x = 10000;
  minPoint.y = 10000;
  maxPoint.x = -1;
  maxPoint.y = -1;
  
  float x1  = t.getPoint(0).x;
  float x2  = t.getPoint(1).x;
  float x3  = t.getPoint(2).x;
  float y1  = t.getPoint(0).y;
  float y2  = t.getPoint(1).y;
  float y3  = t.getPoint(2).y;

  if (x1 < minPoint.x) minPoint.x = x1;
  if (x2 < minPoint.x) minPoint.x = x2;
  if (x3 < minPoint.x) minPoint.x = x3;
  if (y1 < minPoint.y) minPoint.y = y1;
  if (y2 < minPoint.y) minPoint.y = y2;
  if (y3 < minPoint.y) minPoint.y = y3;
  
  if (x1 > maxPoint.x) maxPoint.x = x1;
  if (x2 > maxPoint.x) maxPoint.x = x2;
  if (x3 > maxPoint.x) maxPoint.x = x3;
  if (y1 > maxPoint.y) maxPoint.y = y1;
  if (y2 > maxPoint.y) maxPoint.y = y2;
  if (y3 > maxPoint.y) maxPoint.y = y3;
}

// REFRESH
void refresh(boolean force)
{ 
  if (force == true)
  {
    // Clear screen
    background(inputImage);

    // Force refresh
    for (int i = 0 ; i < triangleArray.size() ; ++i)
    {
      Triangle currentTriangle = (Triangle)triangleArray.get(i);
      currentTriangle.updated = true;
    }
  }
  
  // For each triangle
  for (int i = 0 ; i < triangleArray.size() ; ++i)
  {
    Triangle currentTriangle = (Triangle)triangleArray.get(i);
    // Check if the triangle need to be updated
    if (!currentTriangle.updated) continue;
    // Check if we need to process the triange
    if (!voronoi && deleteBorder && containBorderPointIdx(currentTriangle)) continue;
    // Retrieve bounding box of the triangle
    Point minPoint = new Point(0,0);
    Point maxPoint = new Point(0,0);
    boundingBox(currentTriangle,minPoint,maxPoint);
    // For each pixels
    for (int x = (int)minPoint.x; x < (int)maxPoint.x ; x++)
    {
      for (int y = (int)minPoint.y; y < (int)maxPoint.y ; y++)
      {
        int pixelIdx = y * inputImage.width + x;
        color currentColor = inputImage.pixels[pixelIdx];
        Point currentPoint = new Point((float)x,(float)y);
        if ( intersectTriangle(currentTriangle,currentPoint) )
        {
          currentTriangle.addColor(currentColor);
        }
      } 
    }
  }
  
  // Compute average color for each triangles
  for (int i = 0 ; i < triangleArray.size() ; ++i)
  {
    Triangle currentTriangle = (Triangle)triangleArray.get(i);
    currentTriangle.computeColor();
  }
  
  if (voronoi)
  {
    // Compute average color each quad
    for (int i = 0 ; i < quadArray.size() ; ++i)
    {
      Quad currentQuad = (Quad)quadArray.get(i);
      Triangle t1 = (Triangle)triangleArray.get(currentQuad.triangleIdx1);
      Triangle t2 = (Triangle)triangleArray.get(currentQuad.triangleIdx2);

      // Average color t1
      t1.addColor(t2.c);
      t1.count = 2;
      t1.computeColor();
      
      // Retrieve the 4th point in t2
      int fourth = -1;
      if (t2.idx1 != t1.idx1 && t2.idx1 != t1.idx2 && t2.idx1 != t1.idx3) fourth = t2.idx1;
      if (t2.idx2 != t1.idx1 && t2.idx2 != t1.idx2 && t2.idx2 != t1.idx3) fourth = t2.idx2;
      if (t2.idx3 != t1.idx1 && t2.idx3 != t1.idx2 && t2.idx3 != t1.idx3) fourth = t2.idx3;
      Point fourthPoint = (Point)pointArray.get(fourth);
      
      fill(color(red(t1.c),green(t1.c),blue(t1.c),alphaFactor));
      if (outlined)
        stroke(color(red(t1.c)/2,green(t1.c)/2,blue(t1.c)/2,alphaFactor));
      else
        stroke(color(red(t1.c),green(t1.c),blue(t1.c),alphaFactor));
      quad(t1.getPoint(0).x,t1.getPoint(0).y,t1.getPoint(1).x,t1.getPoint(1).y,t1.getPoint(2).x,t1.getPoint(2).y,fourthPoint.x,fourthPoint.y); 
    }
  }
  else
  {
    // Draw the triangles
    for (int i = 0 ; i < triangleArray.size() ; ++i)
    {
      Triangle t = (Triangle)triangleArray.get(i);
      // Check if the triangle need to be drawn
      if (!t.updated) continue;
      if (deleteBorder && containBorderPointIdx(t)) continue;
      fill(color(red(t.c),green(t.c),blue(t.c),alphaFactor));
      if (outlined)
        stroke(color(red(t.c)/2,green(t.c)/2,blue(t.c)/2,alphaFactor));
      else
        stroke(color(red(t.c),green(t.c),blue(t.c),alphaFactor));
      triangle(t.getPoint(0).x,t.getPoint(0).y,t.getPoint(1).x,t.getPoint(1).y,t.getPoint(2).x,t.getPoint(2).y);
    }
  }
  
   // Reinitialized the updated attribute for each triangles
  for (int i = 0 ; i < triangleArray.size() ; ++i)
  {
    Triangle currentTriangle = (Triangle)triangleArray.get(i);
    currentTriangle.updated = false;
  }
  
  // Redraw
  redraw();
}

// CROSS PRODUCT
Point crossProduct(Point v)
{
  Point res = new Point(-v.y,v.x);
  return res;
}

// DOT PRODUCT
double dotProduct(Point v1, Point v2)
{
  return v1.x * v2.x + v1.y * v2.y;
}

// SAME SIDE
boolean sameSide(Point p1, Point p2, Point a, Point b)
{
  Point n = crossProduct(b.less(a));
  double res1 = dotProduct(n,p1.less(a));
  double res2= dotProduct(n,p2.less(a));
  
  if ( (res1 >= 0 && res2 >= 0) || (res1 <= 0 && res2 <= 0) )
    return true;
  
  return false;
}

// LINE INTERSECT LINE
boolean intersectLine(Point p1, Point p2, Point p3, Point p4, Point intersection)
{
  float x1 = p1.x;
  float y1 = p1.y;
  float x2 = p2.x;
  float y2 = p2.y;
  float x3 = p3.x;
  float y3 = p3.y;
  float x4 = p4.x;
  float y4 = p4.y;

  float d = (x1-x2)*(y3-y4) - (y1-y2)*(x3-x4);
  if (d == 0) return false;
    
  float xi = ((x3-x4)*(x1*y2-y1*x2)-(x1-x2)*(x3*y4-y3*x4))/d;
  float yi = ((y3-y4)*(x1*y2-y1*x2)-(y1-y2)*(x3*y4-y3*x4))/d;
  
  // Intersection (even if not in segments)
  intersection.x = xi;
  intersection.y = yi;

  if (xi < Math.min(x1,x2) || xi > Math.max(x1,x2)) return false;
  if (xi < Math.min(x3,x4) || xi > Math.max(x3,x4)) return false;
  return true;
}

// POINT INTERSECT TRIANGLE
boolean intersectTriangle(Triangle pTriangle, Point p)
{
  Point a = pTriangle.getPoint(0);
  Point b = pTriangle.getPoint(1);
  Point c = pTriangle.getPoint(2);

  if (sameSide(p,a,b,c) && sameSide(p,b,a,c) && sameSide(p,c,a,b))
    {
      return true;
    }
  return false;
}

// INTERSECT CIRCLE
boolean inCircle(Point circleCenter, float circleRadius, Point p)
{
  return circleCenter.distanceTo(p) < circleRadius;
}

// TRIANGLE CENTER
Point triangleCenter(Triangle t)
{
  // The triangle center is the intersection of two of the normals
  Point normal1 = t.getPoint(1).less(t.getPoint(0));
  Point normal2 = t.getPoint(2).less(t.getPoint(0));
  
  normal1 = crossProduct(normal1);
  normal2 = crossProduct(normal2);
  
  Point middle1 = t.getPoint(1).middle(t.getPoint(0));
  Point middle2 = t.getPoint(2).middle(t.getPoint(0));
  
  Point point1 = middle1.plus(normal1);
  Point point2 = middle2.plus(normal2);
  
  Point intersection = new Point(0,0);
  intersectLine(middle1,point1,middle2,point2,intersection);
  
  return intersection;
}

// IS CIRCUMSCRIBED
boolean isCircumscribed(Triangle t, Point p)
{
  Point center = triangleCenter(t);
  float radius = t.getPoint(0).distanceTo(center);
  
  return inCircle(center,radius,p);
}

// LINE INTERSECT TRIANGLE
boolean intersectTriangle(Triangle pTriangle, Point p1, Point p2)
{
  Point a = pTriangle.getPoint(0);
  Point b = pTriangle.getPoint(1);
  Point c = pTriangle.getPoint(2);
  
  Point intersection = new Point(0,0);

  // Intersection?
  if (intersectLine(p1,p2,a,b,intersection) || intersectLine(p1,p2,a,c,intersection) || intersectLine(p1,p2,b,c,intersection) )
  {
      return true;
  }
  
  return false;
}

class Index
{
  Index(int pIdx)
  {
    idx = pIdx;
  }
  int idx; 
}

void addIdx(ArrayList pointIdxArray, int idx)
{
  Index newIndex = new Index(idx);
  pointIdxArray.add(newIndex);
}

boolean removeIdx(ArrayList pointIdxArray, int idx)
{
  for (int i = 0 ; i < pointIdxArray.size() ; ++i)
  {
    Index index = (Index)pointIdxArray.get(i);
    if (index.idx == idx)
    {
      pointIdxArray.remove(i);
      return true;
    }
  }
  return false;
}

// FLIP EDGE
int flipNb = 0;
boolean flipEdge(Triangle t1, Triangle t2, int newPointIdx)
{
  // Add the point of t1
  ArrayList pointIdxT1Array = new ArrayList();
  pointIdxT1Array.add(new Index(t1.idx1));
  pointIdxT1Array.add(new Index(t1.idx2));
  pointIdxT1Array.add(new Index(t1.idx3));
  
  // Remove the point of t2 in pointIdxT1Array
  ArrayList couplePointIdxArray = new ArrayList();
  if (removeIdx(pointIdxT1Array,t2.idx1))
  {
    couplePointIdxArray.add(new Index(t2.idx1));
  }
  if (removeIdx(pointIdxT1Array,t2.idx2))
  {
    couplePointIdxArray.add(new Index(t2.idx2));
  }
  if (removeIdx(pointIdxT1Array,t2.idx3))
  {
    couplePointIdxArray.add(new Index(t2.idx3));
  }
 
 // Check if it's the good triangle
 if (pointIdxT1Array.size() != 1)
 {
   // It's not the good triangle
    return false; 
 }
 
  // Retrieve the last point
  Index lastIndex = (Index)pointIdxT1Array.get(0);
  int lastIdx = lastIndex.idx;
  
  // Retrieve the two other points
  Index commonIndex1 = (Index)couplePointIdxArray.get(0);
  Index commonIndex2 = (Index)couplePointIdxArray.get(1);
  int commonIdx1 = commonIndex1.idx;
  int commonIdx2 = commonIndex2.idx;
  
  // Flip the edge of the triangle  
  // First triangle
  t1.idx1 = newPointIdx;
  t1.idx2 = lastIdx;
  t1.idx3 = commonIdx1;
  
  // Second triangle
  t2.idx1 = newPointIdx;
  t2.idx2 = lastIdx;
  t2.idx3 = commonIdx2;
  
  // Update updated attribute
  t1.updated = true;
  t2.updated = true;
  
  return true;
}

// DELAUNAY
void delaunay(int newPointIdx)
{
  // Retrieve new point
  Point newPoint = (Point)pointArray.get(newPointIdx);
 
  // Find which triangle contains the point
  Triangle t = null;
  int idx = 0;
  for (idx = 0 ; idx < triangleArray.size() ; ++idx)
  {
    Triangle currentTriangle = (Triangle)triangleArray.get(idx);
    if ( intersectTriangle(currentTriangle,newPoint) )
    {
      t = currentTriangle;
      break;
    }
  }
  
  if (t != null)
  {
    // Retrieve the point index of the triangle
    int idx1 = t.idx1;
    int idx2 = t.idx2;
    int idx3 = t.idx3;
    
    // Remove the current triangle
    triangleArray.remove(idx);
    
    // Create new triangles with this point
    Triangle t1 = new Triangle(newPointIdx,idx1,idx2);
    Triangle t2 = new Triangle(newPointIdx,idx1,idx3);
    Triangle t3 = new Triangle(newPointIdx,idx2,idx3);
    triangleArray.add(t1);
    triangleArray.add(t2);
    triangleArray.add(t3);
    
    // Fnd which triangles have a circumscribed circle encompassing the vertex
    for (int i = 0 ; i < triangleArray.size() ; ++i)
    {
      Triangle currentTriangle = (Triangle)triangleArray.get(i);
      if(isCircumscribed(currentTriangle,newPoint))
      {
        // Flip the edge of one of those triangles:
        if (flipEdge(currentTriangle,t1,newPointIdx)) continue;
        if (flipEdge(currentTriangle,t2,newPointIdx)) continue;
        if (flipEdge(currentTriangle,t3,newPointIdx)) continue;
      }
    }
  }
}

// POINT EXIST
boolean pointExist(int x, int y)
{
  for (int i = 0; i < pointArray.size() ; ++i)
  {
    Point p = (Point)pointArray.get(i);
    if (p.x == x && p.y == y) return true;
  }
  return false;
}

// POINT DISTANCE 
boolean pointDistance(int x, int y, float distance)
{
  Point newPoint = new Point(x,y);
  for (int i = 0; i < pointArray.size() ; ++i)
  {
    Point p = (Point)pointArray.get(i);
    if (p.distanceTo(newPoint) < distance) return true;
  }
  return false;
}

// REMOVE POINT INDEX
void removePointIdx(int index)
{
  // Copy all points except the last one
  ArrayList newPointArray = new ArrayList();
  for (int i = 0; i < pointArray.size(); ++i)
  {
    if (i != index)
    {
      Point p = (Point)pointArray.get(i);
      newPointArray.add(p);
    }
  }
  
  // Erase all
  pointArray.clear();
  triangleArray.clear();
  
  // Setup
  setup();
   
  // Add every points
  for (int i = 4; i < newPointArray.size() ; ++i)
  {
    // Add point
    Point p = (Point)newPointArray.get(i);
    pointArray.add(p);
    
    // Apply Delaunay
    delaunay(i); 
  }

  // Refresh screen
  refresh(true);
}
    

// REMOVE POINT NEAR
void removePointNear(int x, int y)
{
  float distance = 10;
  Point clickedPoint = new Point(x,y);
  int candidatePointIdx = -1;
  // Look for the nearest point
  for (int i = 0; i < pointArray.size(); ++i)
  {
    Point p = (Point)pointArray.get(i);
    float currentDistance = p.distanceTo(clickedPoint);
    if (currentDistance < distance)
    {
      candidatePointIdx = i;
      distance = currentDistance;
    }
  }
  
  if (candidatePointIdx > 3) // We don't want the border to be deleted
  {
    // Remove point index
    removePointIdx(candidatePointIdx);
  }
}

// TRIANGLE BARYCENTER
Point triangleBarycenter(Triangle t)
{
  Point barycenter = new Point(
    (t.getPoint(0).x + t.getPoint(1).x + t.getPoint(2).x) / 3.,
    (t.getPoint(0).y + t.getPoint(1).y + t.getPoint(2).y) / 3.);
  return barycenter;
}

// APPLY VORONOI
ArrayList delaunayTriangleArray =  new ArrayList();
ArrayList delaunayPointArray =  new ArrayList();
void applyVoronoi()
{
  if (voronoi)
  {
    // Create a copy of the triangle and point array
    delaunayTriangleArray = (ArrayList)triangleArray.clone();
    delaunayPointArray = (ArrayList)pointArray.clone();
    triangleArray.clear();

    // Create 3 quad for each triangles
    for (int i = 0 ; i < delaunayTriangleArray.size() ; ++i)
    {
      Triangle currentTriangle = (Triangle)delaunayTriangleArray.get(i);

      // Create new points
      Point center = triangleBarycenter(currentTriangle);
      Point m1 = currentTriangle.getPoint(0).middle(currentTriangle.getPoint(1));
      Point m2 = currentTriangle.getPoint(0).middle(currentTriangle.getPoint(2));
      Point m3 = currentTriangle.getPoint(1).middle(currentTriangle.getPoint(2));

      // Index
      int centerIdx = pointArray.size();
      int m1Idx = pointArray.size()+1;
      int m2Idx = pointArray.size()+2;
      int m3Idx = pointArray.size()+3;

      // Add those points
      pointArray.add(center);
      pointArray.add(m1);
      pointArray.add(m2);
      pointArray.add(m3);

      // Create triangles
      Triangle t1q1 = new Triangle(currentTriangle.idx1,m1Idx,centerIdx);
      Triangle t2q1 = new Triangle(currentTriangle.idx1,m2Idx,centerIdx);
      Triangle t1q2 = new Triangle(currentTriangle.idx2,m1Idx,centerIdx);
      Triangle t2q2 = new Triangle(currentTriangle.idx2,m3Idx,centerIdx);
      Triangle t1q3 = new Triangle(currentTriangle.idx3,m2Idx,centerIdx);
      Triangle t2q3 = new Triangle(currentTriangle.idx3,m3Idx,centerIdx);

      // Index
      int t1q1Idx = triangleArray.size();
      int t2q1Idx = triangleArray.size()+1;
      int t1q2Idx = triangleArray.size()+2;
      int t2q2Idx = triangleArray.size()+3;
      int t1q3Idx = triangleArray.size()+4;
      int t2q3Idx = triangleArray.size()+5;

      // Add those triangles
      triangleArray.add(t1q1);
      triangleArray.add(t2q1);
      triangleArray.add(t1q2);
      triangleArray.add(t2q2);
      triangleArray.add(t1q3);
      triangleArray.add(t2q3);

      // Create quads
      Quad quad1 = new Quad(t1q1Idx,t2q1Idx);
      Quad quad2 = new Quad(t1q2Idx,t2q2Idx);
      Quad quad3 = new Quad(t1q3Idx,t2q3Idx);

      // Add quads
      quadArray.add(quad1);
      quadArray.add(quad2);
      quadArray.add(quad3);
    }

    // Refresh
    refresh(true);
  }
  else
  {
    // Refresh
    triangleArray = delaunayTriangleArray;
    pointArray = delaunayPointArray;
    refresh(true);
  }
}

// MOUSE CLICK
void mousePressed()
{
  if (!imageLoaded) return;
  
  if (suppresion)
  {
    removePointNear(mouseX,mouseY);
    return ; 
  }
  
  // Check if that point already exists
  if (pointExist(mouseX,mouseY)) return;

  // Add the point
  Point newPoint = new Point(mouseX,mouseY);  
  pointArray.add(newPoint);
  int newPointIdx = pointArray.size() - 1;
  
  // Apply Delaunay
  delaunay(newPointIdx);
  
  // Refresh screen
  refresh(false);
}

// LOAD PROJECT
void loadProject()
{
  // Open a file
  String path = "export.cfg";
  if (!path.isEmpty())
  {
    // Erase all
    pointArray.clear();
    triangleArray.clear();
    quadArray.clear();
    
    // Setup
    setup();
    
    BufferedReader reader = createReader(path);
    String line;
    try {
    line = reader.readLine();
    } catch (IOException e) {
      e.printStackTrace();
      line = null;
    }
    if (line != null)
    {
      // Point array
      String[] coords = split(line, " ");
      for (int i = 0 ; i < coords.length ; i += 2)
      {
        float x = float(coords[i]);
        float y = float(coords[i+1]);
        Point p = new Point(x,y);
        pointArray.add(p);
        delaunay(i/2+4);
      }
    }       
    // Refresh
    refresh(true);
  }
}

// SAVE PICTURE
void savePicture()
{
  // Save the picture
  String path = "export.jpg";
  if (!path.isEmpty())
  {
    save(path);
    path = "export.cfg";
    PrintWriter output = createWriter(path);
    for (int i = 4; i < pointArray.size() ; ++i)
    {
      Point p = (Point)pointArray.get(i);
      output.print(p.x + " " + p.y);
      if (i == pointArray.size() - 1)
        output.println("");
      else
        output.print(" ");
    }
    output.flush();
    output.close();
  }
}

// KEY PRESSED
boolean alphaEnabled = false;
void keyPressed()
{
  if (!imageLoaded) return;
  if (key == ' ')
  {
    // Update the main factor
    alphaEnabled = !alphaEnabled;
    alphaFactor = alphaEnabled ? userAlphaFactor : 255;
    
    // Refresh
    refresh(true);
  }
  else if (key == 'b')
  {
    // Update delete border
    deleteBorder = !deleteBorder;
    
    // Refresh
    refresh(true);
  }
  else if (key == 'f')
  {
    // Update delete border
    outlined = !outlined;
    
    // Refresh
    refresh(true);
  }
  else if (control && key == 'r')
  {
    // Erase all
    pointArray.clear();
    triangleArray.clear();
    quadArray.clear();
    voronoi = false;
    
     // Setup
     setup();
     
     // Redraw
     redraw();

    control = false;
  }
  else if (control && key == 's')
  {
    savePictureEnabled = true;
    redraw();
    control = false;
  }
  else if (control && key == 'o')
  {
    openProjectEnabled = true;
    redraw();
    control = false;
  }
  else if (control && key == 'z')
  {
    // Remove last point
    removePointIdx(pointArray.size()-1);
  }
  else if (keyCode == SHIFT)
  {
    cursor(CROSS);
    suppresion = true;
  }
  else if (keyCode == 157 || keyCode == CONTROL)
  {
    control = true;
  }
  else if (key == 'v')
  {
    voronoi = !voronoi;
    applyVoronoi();
  }
  else if (key == 'm')
  {
  
    // Erase all
    pointArray.clear();
    triangleArray.clear();
    quadArray.clear();
    
    // Setup
    setup();
    
    // Create randoms points
    for (int i = 4; i < 2000; ++i)
    {
      int x,y;
      Point p;
      do
      {
        x = (int)random(10,inputImage.width - 10);
        y = (int)random(10,inputImage.height - 10);
        p = new Point(x,y);
      }
      while (pointDistance(x,y,3.0));
      pointArray.add(p);
      delaunay(i);
      refresh(false);
    }
  }
  else if (key == 'e')
  {
    // Export to obj
    print("Export object");
    String path = "export.obj";
    if (!path.isEmpty())
    {
      save(path);
      savePicture();
      
      PrintWriter output = createWriter(path);
      
      // Header
      output.println("#export.obj");
      output.println("");
      
      // Material
      output.println("mtllib export.mtl");
      output.println("");
      
      // Object
      output.println("o export");
      output.println("");
      
      // Set winding order
      for (int i = 0 ; i < triangleArray.size() ; ++i)
      {
        Triangle currentTriangle = (Triangle)triangleArray.get(i);
        currentTriangle.windingOrder();
      }
      
      // Vertex
      for (int i = 0; i < pointArray.size() ; ++i)
      {
        Point p = (Point)pointArray.get(i);
        float z = 0;
        int count = 0;
        for (int j = 0 ; j < triangleArray.size() ; ++j)
        {
          Triangle currentTriangle = (Triangle)triangleArray.get(j);
          if (currentTriangle.idx1 == i || currentTriangle.idx2 == i || currentTriangle.idx3 == i)
          {
            z += (currentTriangle.r + currentTriangle.g + currentTriangle.b) / (3.0*255.0);
            count++;
          }
        }
        z = (z / count);
        z = z / 7;
        output.println("v " + p.x / inputImage.width  + " " + (1-p.y) / inputImage.height + " " + z);
      }
      output.println("");
      
      // Normal
      output.println("vn  0.0  0.0  1.0");
      output.println("");
      
      // Texture
      for (int i = 0; i < pointArray.size() ; ++i)
      {
        Point p = (Point)pointArray.get(i);
        output.println("vt " + p.x / inputImage.width  + " " + (1-p.y) / inputImage.height);
      }
      
      output.println("");
      
      // Faces
      output.println("usemtl export_mtl");
      for (int i = 0 ; i < triangleArray.size() ; ++i)
      {
        Triangle currentTriangle = (Triangle)triangleArray.get(i);
        if (containBorderPointIdx(currentTriangle)) continue;        
        
        String triplet1 = (currentTriangle.idx1+1) + "/" + (currentTriangle.idx1+1) + "/1";
        String triplet2 = (currentTriangle.idx2+1) + "/" + (currentTriangle.idx2+1) + "/1";
        String triplet3 = (currentTriangle.idx3+1) + "/" + (currentTriangle.idx3+1) + "/1";
        
        output.println("f " + triplet1 + " " +  triplet2 + " " + triplet3);
      }
      output.println("");
      
      output.flush();
      output.close();
      
      // Save the picture
      savePictureEnabled = true;
    }
  }
  else if(keyCode == UP)
  {
    if (alphaEnabled && userAlphaFactor < 248)
    {
      userAlphaFactor += 8;
      alphaFactor = userAlphaFactor;
      refresh(true);
    }
  }
  else if(keyCode == DOWN)
  {
    if (alphaEnabled && userAlphaFactor > 8)
    {
      userAlphaFactor -= 8;
      alphaFactor = userAlphaFactor;
      refresh(true);
    }
  }
}

void keyReleased()
{
  if (keyCode == SHIFT)
  {
    cursor(ARROW);
    suppresion = false;
  }
  else if (keyCode == 157 || keyCode == CONTROL)
  {
    control = false;
  }
}
