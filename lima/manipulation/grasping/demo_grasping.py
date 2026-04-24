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
from pathlib import Path

from lima.agents.agent import agent
from lima.core.blueprints import autoconnect
from lima.hardware.sensors.camera.realsense import realsense_camera
from lima.manipulation.grasping import graspgen
from lima.manipulation.grasping.grasping import grasping_module
from lima.perception.detection.detectors.yoloe import YoloePromptMode
from lima.perception.object_scene_registration import object_scene_registration_module
from lima.robot.foxglove_bridge import foxglove_bridge

camera_module = realsense_camera(enable_pointcloud=False)

demo_grasping = autoconnect(
    camera_module,
    object_scene_registration_module(
        target_frame="camera_color_optical_frame", prompt_mode=YoloePromptMode.PROMPT
    ),
    grasping_module(),
    graspgen(
        docker_file_path=Path(__file__).parent / "docker_context" / "Dockerfile",
        docker_build_context=Path(__file__).parent.parent.parent.parent,  # repo root
        gripper_type="robotiq_2f_140",  # out of the bosx ships "robotiq_2f_140", "franka_panda", "single_suction_cup_30mm
        num_grasps=400,
        topk_num_grasps=100,
        filter_collisions=False,
        save_visualization_data=False,  # to just see the visualization simply run ``grasping/visualize_grasps.py`` as a standalone script
        docker_volumes=[
            ("/tmp", "/tmp", "rw")
        ],  # Grasp visualization debug standalone: python -m lima.manipulation.grasping.visualize_grasps
    ),
    foxglove_bridge(),
    agent(),
).global_config(viewer="foxglove")
