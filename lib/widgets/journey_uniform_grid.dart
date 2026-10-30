import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Every card gets the tallest intrinsic height at the current column width.
/// Width, language and text scaling can change that height without clipping.
class JourneyUniformGrid extends MultiChildRenderObjectWidget {
  const JourneyUniformGrid({
    super.key,
    this.columns,
    this.minimumColumnWidth = 145,
    this.spacing = 12,
    required super.children,
  });
  final int? columns;
  final double minimumColumnWidth, spacing;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _JourneyGridBox(columns, minimumColumnWidth, spacing);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _JourneyGridBox)
      ..columns = columns
      ..minimumColumnWidth = minimumColumnWidth
      ..spacing = spacing;
  }
}

class _JourneyCellData extends ContainerBoxParentData<RenderBox> {}

class _JourneyGridBox extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  _JourneyGridBox(this._columns, this._minimumColumnWidth, this._spacing);
  int? _columns;
  double _minimumColumnWidth, _spacing;
  set columns(int? value) {
    if (_columns != value) {
      _columns = value;
      markNeedsLayout();
    }
  }

  set minimumColumnWidth(double value) {
    if (_minimumColumnWidth != value) {
      _minimumColumnWidth = value;
      markNeedsLayout();
    }
  }

  set spacing(double value) {
    if (_spacing != value) {
      _spacing = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) {
      child.parentData = _JourneyCellData();
    }
  }

  ({int columns, int rows, double width, double height}) _measure(
    double width,
  ) {
    final columns = math.max(
      1,
      _columns ??
          ((width + _spacing) / (_minimumColumnWidth + _spacing)).floor(),
    );
    final cellWidth = math.max(
      0.0,
      (width - (columns - 1) * _spacing) / columns,
    );
    var height = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      height = math.max(height, child.getMaxIntrinsicHeight(cellWidth));
    }
    return (
      columns: columns,
      rows: (childCount + columns - 1) ~/ columns,
      width: cellWidth,
      height: height,
    );
  }

  Size _size(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : 320.0;
    final d = _measure(width);
    return constraints.constrain(
      Size(width, d.rows * d.height + math.max(0, d.rows - 1) * _spacing),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _size(constraints);
  @override
  void performLayout() {
    size = _size(constraints);
    final d = _measure(size.width);
    var i = 0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      child.layout(
        BoxConstraints.tight(Size(d.width, d.height)),
        parentUsesSize: true,
      );
      (child.parentData! as ContainerBoxParentData<RenderBox>).offset = Offset(
        (i % d.columns) * (d.width + _spacing),
        (i ~/ d.columns) * (d.height + _spacing),
      );
      i++;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
