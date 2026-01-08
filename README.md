<div align="center">
  <img src="qml/livepose/resources/images/LivePose_logo.png" alt="LivePose Logo" width="80">
  
  <p>
    <a href="https://github.com/sat-mtl/livepose/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/sat-mtl/livepose/build.yml?style=flat-square&label=build" alt="Build"></a>
    <img src="https://img.shields.io/badge/Platform-macOS_|_Linux_|_Windows-blue?style=flat-square" alt="Platform">
    <br>
    <a href="https://ossia.io"><img src="https://img.shields.io/badge/Powered_by-ossia_score-7B68EE?style=flat-square" alt="ossia score"></a>
    <a href="https://sat.qc.ca"><img src="https://img.shields.io/badge/Developed at-Société_des_Arts_Technologiques-00A86B?style=flat-square" alt="SAT"></a>
  </p>
</div>

LivePose offers a simple way to run computer vision models on live video and send the results to any [OSC](https://en.wikipedia.org/wiki/Open_Sound_Control)-compatible application. With no programming required, load a model, select your camera, and start streaming data. This release uses [ONNX](https://github.com/onnx/onnx), an open standard for machine learning models, providing a lightweight, cross-platform GUI application.

## Features

- 🧠 Load `.onnx` models (BlazePose, YOLOv8 Pose, ResNet)
- 📷 Automatic camera detection (plug and play)
- 🎬 Live video preview
- 📡 Configurable OSC output

## Use Cases

Connect your output data to **[Pure Data](https://puredata.info/)**, **[Max/MSP](https://cycling74.com/downloads)**, **[Processing](https://processing.org/)**, **[p5.js](https://p5js.org/)**, **[TouchDesigner](https://derivative.ca/UserGuide/TouchDesigner)**, **[SuperCollider](https://supercollider.github.io/)**, **[openFrameworks](https://openframeworks.cc/)**, or any software that receives [OSC](https://en.wikipedia.org/wiki/Open_Sound_Control). Useful for interactive installations, live performance, prototyping, and experimentation. Check [awesome-creative-coding](https://github.com/terkelg/awesome-creative-coding) for more tools and resources.

## Credits

Developed by the [Société des Arts Technologiques](https://sat.qc.ca), built on [ossia score](https://ossia.io).