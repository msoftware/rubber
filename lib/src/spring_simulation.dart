// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/physics.dart';

class RubberSpringSimulation extends Simulation {

  int zeros = 0;
  double stopTime = 1000.0;

  RubberSpringSimulation(
      SpringDescription spring,
      double start,
      double end,
      double velocity, {
        Tolerance tolerance = Tolerance.defaultTolerance,
      }) : _endPosition = end,
        _solution = _SpringSolution(spring, start - end, velocity),
        super(tolerance: tolerance);

  final double _endPosition;
  final _SpringSolution _solution;

  @override
  double x(double time) {

    if(nearZero(_solution.x(time),0.0001)) {
      return _endPosition;
    }
    return _endPosition + _solution.x(time);
  }

  @override
  double dx(double time) => _solution.dx(time);

  @override
  bool isDone(double time) {
    if(nearZero(_solution.x(time),0.0001))
      zeros++;

    if(zeros >= 30) {
      stopTime = time;
      return true;
    }
    return false;
  }

  @override
  String toString() => '$runtimeType(end: $_endPosition)';
}

// SPRING IMPLEMENTATIONS

abstract class _SpringSolution {
  factory _SpringSolution(
      SpringDescription spring,
      double initialPosition,
      double initialVelocity
      ) {
    assert(spring != null);
    assert(spring.mass != null);
    assert(spring.stiffness != null);
    assert(spring.damping != null);
    assert(initialPosition != null);
    assert(initialVelocity != null);
    final double cmk = spring.damping * spring.damping - 4 * spring.mass * spring.stiffness;
    if (cmk == 0.0)
      return _CriticalSolution(spring, initialPosition, initialVelocity);
    if (cmk > 0.0)
      return _OverdampedSolution(spring, initialPosition, initialVelocity);
    return _UnderdampedSolution(spring, initialPosition, initialVelocity);
  }

  double x(double time);
  double dx(double time);
  SpringType get type;
}

class _CriticalSolution implements _SpringSolution {
  factory _CriticalSolution(
      SpringDescription spring,
      double distance,
      double velocity
      ) {
    final double r = -spring.damping / (2.0 * spring.mass);
    final double c1 = distance;
    final double c2 = velocity / (r * distance);
    return _CriticalSolution.withArgs(r, c1, c2);
  }

  _CriticalSolution.withArgs(double r, double c1, double c2)
      : _r = r,
        _c1 = c1,
        _c2 = c2;

  final double _r, _c1, _c2;

  @override
  double x(double time) {
    return (_c1 + _c2 * time) * math.pow(math.e, _r * time);
  }

  @override
  double dx(double time) {
    final double power = math.pow(math.e, _r * time);
    return _r * (_c1 + _c2 * time) * power + _c2 * power;
  }

  @override
  SpringType get type => SpringType.criticallyDamped;
}

class _OverdampedSolution implements _SpringSolution {
  factory _OverdampedSolution(
      SpringDescription spring,
      double distance,
      double velocity
      ) {
    final double cmk = spring.damping * spring.damping - 4 * spring.mass * spring.stiffness;
    final double r1 = (-spring.damping - math.sqrt(cmk)) / (2.0 * spring.mass);
    final double r2 = (-spring.damping + math.sqrt(cmk)) / (2.0 * spring.mass);
    final double c2 = (velocity - r1 * distance) / (r2 - r1);
    final double c1 = distance - c2;
    return _OverdampedSolution.withArgs(r1, r2, c1, c2);
  }

  _OverdampedSolution.withArgs(double r1, double r2, double c1, double c2)
      : _r1 = r1,
        _r2 = r2,
        _c1 = c1,
        _c2 = c2;

  final double _r1, _r2, _c1, _c2;

  @override
  double x(double time) {
    return _c1 * math.pow(math.e, _r1 * time) +
        _c2 * math.pow(math.e, _r2 * time);
  }

  @override
  double dx(double time) {
    return _c1 * _r1 * math.pow(math.e, _r1 * time) +
        _c2 * _r2 * math.pow(math.e, _r2 * time);
  }

  @override
  SpringType get type => SpringType.overDamped;
}

class _UnderdampedSolution implements _SpringSolution {
  factory _UnderdampedSolution(
      SpringDescription spring,
      double distance,
      double velocity
      ) {
    final double w = math.sqrt(4.0 * spring.mass * spring.stiffness -
        spring.damping * spring.damping) / (2.0 * spring.mass);
    final double r = -(spring.damping / 2.0 * spring.mass);
    final double c1 = distance;
    final double c2 = (velocity - r * distance) / w;
    return _UnderdampedSolution.withArgs(w, r, c1, c2);
  }

  _UnderdampedSolution.withArgs(double w, double r, double c1, double c2)
      : _w = w,
        _r = r,
        _c1 = c1,
        _c2 = c2;

  final double _w, _r, _c1, _c2;

  @override
  double x(double time) {
    return math.pow(math.e, _r * time) *
        (_c1 * math.cos(_w * time) + _c2 * math.sin(_w * time));
  }

  @override
  double dx(double time) {
    final double power = math.pow(math.e, _r * time);
    final double cosine = math.cos(_w * time);
    final double sine = math.sin(_w * time);
    return      power * (_c2 * _w * cosine - _c1 * _w * sine) +
        _r * power * (_c2 *      sine   + _c1 *      cosine);
  }

  @override
  SpringType get type => SpringType.underDamped;
}