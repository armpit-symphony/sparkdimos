#!/usr/bin/env python3
# Copyright 2025-2026 LIMA Robotics Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from lima.agents.agent import agent
from lima.core.blueprints import autoconnect
from lima.hardware.sensors.camera.realsense import realsense_camera
from lima.hardware.sensors.camera.zed import zed_camera
from lima.perception.detection.detectors.yoloe import YoloePromptMode
from lima.perception.object_scene_registration import object_scene_registration_module
from lima.robot.foxglove_bridge import foxglove_bridge

camera_choice = "zed"

if camera_choice == "realsense":
    camera_module = realsense_camera(enable_pointcloud=False)
elif camera_choice == "zed":
    camera_module = zed_camera(enable_pointcloud=False)
else:
    raise ValueError(f"Invalid camera choice: {camera_choice}")

demo_object_scene_registration = autoconnect(
    camera_module,
    object_scene_registration_module(target_frame="world", prompt_mode=YoloePromptMode.LRPC),
    foxglove_bridge(),
    agent(),
).global_config(viewer="foxglove")
