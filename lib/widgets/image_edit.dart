import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as ImageLib;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart' as PathProvider;

import '../configs/image_picker_configs.dart';
import '../utils/image_utils.dart';

class ImageEdit extends StatefulWidget {
  final File file;
  final String title;
  final int maxWidth;
  final int maxHeight;
  final ImagePickerConfigs configs;

  ImageEdit({@required this.file, @required this.title, this.configs, this.maxWidth = 1920, this.maxHeight = 1080});

  @override
  _ImageEditState createState() => _ImageEditState();
}

class _ImageEditState extends State<ImageEdit> {
  double _contrast = 0;
  double _brightness = 0;
  double _saturation = 0;
  Uint8List _imageBytes;
  Uint8List _orgImageBytes;
  ImageLib.Image _orgImage;
  List<double> _contrastValues = [0];
  List<double> _brightnessValues = [0];
  List<double> _saturationValues = [0];
  bool _isProcessing = false;
  bool _controlExpanded = true;
  ImagePickerConfigs _configs = ImagePickerConfigs();

  @override
  void initState() {
    super.initState();
    if (widget.configs != null) _configs = widget.configs;
  }

  @override
  void dispose() {
    _contrastValues.clear();
    _brightnessValues.clear();
    _saturationValues.clear();
    super.dispose();
  }

  _readImage() async {
    if (_orgImageBytes == null) {
      _orgImageBytes = await widget.file.readAsBytes();
      _orgImage = ImageLib.decodeImage(_orgImageBytes);
    }
    if (_imageBytes == null) {
      _imageBytes = Uint8List.fromList(_orgImageBytes);
    }
    return _imageBytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[_buildDoneButton(context)],
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Expanded(child: _buildImageViewer(context)), _buildAdjustControls(context)],
      ),
    );
  }

  _buildAdjustControls(BuildContext context) {
    var textStyle = TextStyle(color: Colors.white, fontSize: 10);

    if (_controlExpanded) {
      return Container(
        color: Color(0xFF212121),
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _controlExpanded = false;
                });
              },
              child: Container(child: Row(children: [Spacer(), Icon(Icons.keyboard_arrow_down)])),
            ),
            Divider(),
            _buildContrastAdjustControl(context),
            _buildBrightnessAdjustControl(context),
            _buildSaturationAdjustControl(context)
          ],
        ),
      );
    } else {
      return GestureDetector(
        onTap: () {
          setState(() {
            _controlExpanded = true;
          });
        },
        child: Container(
            color: Color(0xFF212121),
            padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("contrast: ${_contrast.toString()}", style: textStyle),
              Text("brightness: ${_brightness.toString()}", style: textStyle),
              Text("saturation: ${_saturation.toString()}", style: textStyle),
              Icon(Icons.keyboard_arrow_up)
            ])),
      );
    }
  }

  _buildDoneButton(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.done),
      onPressed: () async {
        final dir = await PathProvider.getTemporaryDirectory();
        final targetPath = "${dir.absolute.path}/temp_${DateFormat('yyMMdd_hhmmss').format(DateTime.now())}.jpg";
        File file = File(targetPath);
        await file.writeAsBytes(_imageBytes);
        Navigator.of(context).pop(file);
      },
    );
  }

  _buildImageViewer(BuildContext context) {
    var view = () => Container(
        padding: EdgeInsets.all(12.0),
        color: Colors.black,
        child: Image.memory(
          _imageBytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ));

    if (_imageBytes == null)
      return FutureBuilder(
          future: _readImage(),
          builder: (BuildContext context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return view();
            } else
              return Container(
                  child: Center(
                child: CupertinoActivityIndicator(),
              ));
          });
    else
      return view();
  }

  _processImage() async {
    if (_isProcessing) return;

    if (_contrastValues.length > 1 || _brightnessValues.length > 1 || _saturationValues.length > 1) {
      _isProcessing = true;

      // Get last value
      var contrast = _contrastValues.last;
      var brightness = _brightnessValues.last;
      var saturation = _saturationValues.last;

      // Remove old values
      if (_contrastValues.length > 1) _contrastValues.removeRange(0, _contrastValues.length - 1);
      if (_brightnessValues.length > 1) _brightnessValues.removeRange(0, _brightnessValues.length - 1);
      if (_saturationValues.length > 1) _saturationValues.removeRange(0, _saturationValues.length - 1);

      _processImageWithOptions(contrast, brightness, saturation).then((value) {
        _isProcessing = false;

        setState(() {
          _imageBytes = value;
        });

        // Run process image again
        _processImage();
      });
    }
  }

  Future<Uint8List> _processImageWithOptions(double contrast, double brightness, double saturation) async {
    // final ImageEditorOption option = ImageEditorOption();
    // option.addOption(ColorOption.brightness(_calColorOptionValue(brightness)));
    // option.addOption(ColorOption.contrast(_calColorOptionValue(contrast)));
    // option.addOption(ColorOption.saturation(_calColorOptionValue(saturation)));
    // return await ImageEditor.editImage(image: _orgImageBytes, imageEditorOption: option);
    // return await compute(processImageBytes,
    //     {"image": _orgImage, "brightness": brightness, "contrast": contrast, "saturation": saturation});

    return processImageBytes(
        {"image": _orgImage, "brightness": brightness, "contrast": contrast, "saturation": saturation});
  }

  static Uint8List processImageBytes(Map params) {
    var calColorOptionValue = (double value) {
      return (value / 10.0) + 1.0;
    };

    var image = params["image"];
    var bytes = image.getBytes();
    var width = image.width;
    var height = image.height;

    var bMatrix = ImageUtils.brightnessColorMatrix(calColorOptionValue(params["brightness"]));
    var cMatrix = ImageUtils.contrastColorMatrix(calColorOptionValue(params["contrast"]));
    var sMatrix = ImageUtils.saturationColorMatrix(calColorOptionValue(params["saturation"]));
    ImageUtils.applyColorMatrix(bytes, [bMatrix, cMatrix, sMatrix]);

    var outputImage = ImageLib.Image.fromBytes(width, height, bytes);
    return ImageLib.encodePng(outputImage);
  }

  _buildContrastAdjustControl(BuildContext context) {
    var textStyle = TextStyle(color: Colors.white, fontSize: 10);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text("contrast", style: textStyle), Spacer(), Text(_contrast.toString(), style: textStyle)]),
        SliderTheme(
          data: SliderThemeData(
            trackShape: CustomTrackShape(),
          ),
          child: Slider(
            min: -10.0,
            max: 10.0,
            divisions: 40,
            value: _contrast,
            activeColor: Colors.white,
            inactiveColor: Colors.grey,
            onChanged: (value) async {
              if (_contrast != value) {
                setState(() {
                  _contrast = value;
                });
                _contrastValues.add(value);
                _processImage();
              }
            },
          ),
        )
      ]),
    );
  }

  _buildBrightnessAdjustControl(BuildContext context) {
    var textStyle = TextStyle(color: Colors.white, fontSize: 10);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text("brightness", style: textStyle), Spacer(), Text(_brightness.toString(), style: textStyle)]),
        SliderTheme(
          data: SliderThemeData(
            trackShape: CustomTrackShape(),
          ),
          child: Slider(
            min: -10.0,
            max: 10.0,
            divisions: 40,
            value: _brightness,
            activeColor: Colors.white,
            inactiveColor: Colors.grey,
            onChanged: (value) async {
              if (_brightness != value) {
                setState(() {
                  _brightness = value;
                });
                _brightnessValues.add(value);
                _processImage();
              }
            },
          ),
        )
      ]),
    );
  }

  _buildSaturationAdjustControl(BuildContext context) {
    var textStyle = TextStyle(color: Colors.white, fontSize: 10);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text("saturation", style: textStyle), Spacer(), Text(_saturation.toString(), style: textStyle)]),
        SliderTheme(
          data: SliderThemeData(
            trackShape: CustomTrackShape(),
          ),
          child: Slider(
            min: -10.0,
            max: 10.0,
            divisions: 40,
            value: _saturation,
            activeColor: Colors.white,
            inactiveColor: Colors.grey,
            onChanged: (value) async {
              if (_saturation != value) {
                setState(() {
                  _saturation = value;
                });
                _saturationValues.add(value);
                _processImage();
              }
            },
          ),
        )
      ]),
    );
  }
}

class CustomTrackShape extends RoundedRectSliderTrackShape {
  Rect getPreferredRect({
    @required RenderBox parentBox,
    Offset offset = Offset.zero,
    @required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
