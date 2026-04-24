#!/bin/bash
# Script to run both ROS route planner and LIMA together

echo "Starting ROS route planner and LIMA..."

# Variables for process IDs
ROS_PID=""
LIMA_PID=""
RVIZ_PID=""
UNITY_PID=""
SHUTDOWN_IN_PROGRESS=false

# Function to handle cleanup
cleanup() {
    if [ "$SHUTDOWN_IN_PROGRESS" = true ]; then
        return
    fi
    SHUTDOWN_IN_PROGRESS=true

    echo ""
    echo "Shutdown initiated. Stopping services..."

    # First, stop RViz
    if [ -n "$RVIZ_PID" ] && kill -0 $RVIZ_PID 2>/dev/null; then
        echo "Stopping RViz..."
        kill -TERM $RVIZ_PID 2>/dev/null || true
        sleep 1
        if kill -0 $RVIZ_PID 2>/dev/null; then
            kill -9 $RVIZ_PID 2>/dev/null || true
        fi
    fi

    # Stop Unity simulator
    if [ -n "$UNITY_PID" ] && kill -0 $UNITY_PID 2>/dev/null; then
        echo "Stopping Unity simulator..."
        kill -TERM $UNITY_PID 2>/dev/null || true
        sleep 1
        if kill -0 $UNITY_PID 2>/dev/null; then
            kill -9 $UNITY_PID 2>/dev/null || true
        fi
    fi

    # Then, try to gracefully stop LIMA
    if [ -n "$LIMA_PID" ] && kill -0 $LIMA_PID 2>/dev/null; then
        echo "Stopping LIMA..."
        kill -TERM $LIMA_PID 2>/dev/null || true

        # Wait up to 5 seconds for LIMA to stop
        for i in {1..10}; do
            if ! kill -0 $LIMA_PID 2>/dev/null; then
                echo "LIMA stopped cleanly."
                break
            fi
            sleep 0.5
        done

        # Force kill if still running
        if kill -0 $LIMA_PID 2>/dev/null; then
            echo "Force stopping LIMA..."
            kill -9 $LIMA_PID 2>/dev/null || true
        fi
    fi

    # Then handle ROS - send SIGINT to the launch process group
    if [ -n "$ROS_PID" ] && kill -0 $ROS_PID 2>/dev/null; then
        echo "Stopping ROS nodes (this may take a moment)..."

        # Send SIGINT to the process group to properly trigger ROS shutdown
        kill -INT -$ROS_PID 2>/dev/null || kill -INT $ROS_PID 2>/dev/null || true

        # Wait up to 15 seconds for graceful shutdown
        for i in {1..30}; do
            if ! kill -0 $ROS_PID 2>/dev/null; then
                echo "ROS stopped cleanly."
                break
            fi
            sleep 0.5
        done

        # If still running, send SIGTERM
        if kill -0 $ROS_PID 2>/dev/null; then
            echo "Sending SIGTERM to ROS..."
            kill -TERM -$ROS_PID 2>/dev/null || kill -TERM $ROS_PID 2>/dev/null || true
            sleep 2
        fi

        # Final resort: SIGKILL
        if kill -0 $ROS_PID 2>/dev/null; then
            echo "Force stopping ROS..."
            kill -9 -$ROS_PID 2>/dev/null || kill -9 $ROS_PID 2>/dev/null || true
        fi
    fi

    # Clean up any remaining ROS2 processes
    echo "Cleaning up any remaining processes..."
    pkill -f "rviz2" 2>/dev/null || true
    pkill -f "Model.x86_64" 2>/dev/null || true
    pkill -f "ros2" 2>/dev/null || true
    pkill -f "localPlanner" 2>/dev/null || true
    pkill -f "pathFollower" 2>/dev/null || true
    pkill -f "terrainAnalysis" 2>/dev/null || true
    pkill -f "sensorScanGeneration" 2>/dev/null || true
    pkill -f "vehicleSimulator" 2>/dev/null || true
    pkill -f "visualizationTools" 2>/dev/null || true
    pkill -f "far_planner" 2>/dev/null || true
    pkill -f "graph_decoder" 2>/dev/null || true

    echo "All services stopped."
}

# Set up trap to call cleanup on exit
trap cleanup EXIT INT TERM

# Source ROS environment
echo "Sourcing ROS environment..."
source /opt/ros/${ROS_DISTRO:-humble}/setup.bash
source /ros2_ws/install/setup.bash

# Start ROS route planner in background (in new process group)
echo "Starting ROS route planner..."
cd /ros2_ws/src/ros-navigation-autonomy-stack

# Run Unity simulation if available
UNITY_EXECUTABLE="./src/base_autonomy/vehicle_simulator/mesh/unity/environment/Model.x86_64"
if [ -f "$UNITY_EXECUTABLE" ]; then
    echo "Starting Unity simulation environment..."
    "$UNITY_EXECUTABLE" &
    UNITY_PID=$!
else
    echo "Warning: Unity environment not found at $UNITY_EXECUTABLE"
    echo "Continuing without Unity simulation (you may need to provide sensor data)"
    UNITY_PID=""
fi
sleep 3
setsid bash -c 'ros2 launch vehicle_simulator system_simulation_with_route_planner.launch.py' &
ROS_PID=$!
ros2 run rviz2 rviz2 -d src/route_planner/far_planner/rviz/default.rviz &
RVIZ_PID=$!

# Wait a bit for ROS to initialize
echo "Waiting for ROS to initialize..."
sleep 5

# Start LIMA
echo "Starting LIMA navigation bot..."

# Check if the script exists
if [ ! -f "/workspace/lima/lima/navigation/demo_ros_navigation.py" ]; then
    echo "ERROR: demo_ros_navigation.py not found at /workspace/lima/lima/navigation/demo_ros_navigation.py"
    echo "Available files in /workspace/lima/lima/navigation/:"
    ls -la /workspace/lima/lima/navigation/ 2>/dev/null || echo "Directory not found"
else
    echo "Found demo_ros_navigation.py, activating virtual environment..."
    if [ -f "/opt/lima-venv/bin/activate" ]; then
        source /opt/lima-venv/bin/activate
        echo "Python path: $(which python)"
        echo "Python version: $(python --version)"

        # Install lima package if not already installed
        if ! python -c "import lima" 2>/dev/null; then
            echo "Installing lima package..."
            if [ -f "/workspace/lima/setup.py" ] || [ -f "/workspace/lima/pyproject.toml" ]; then
                # Install Unitree extra (includes agents stack + unitree deps used by demo)
                pip install -e "/workspace/lima[unitree]" --quiet
            else
                echo "WARNING: lima package not found at /workspace/lima"
            fi
        fi
    else
        echo "WARNING: Virtual environment not found at /opt/lima-venv, using system Python"
    fi

    echo "Starting demo_ros_navigation.py..."
    # Capture any startup errors
    python /workspace/lima/lima/navigation/demo_ros_navigation.py 2>&1 &
    LIMA_PID=$!

    # Give it a moment to start and check if it's still running
    sleep 2
    if kill -0 $LIMA_PID 2>/dev/null; then
        echo "LIMA started successfully with PID: $LIMA_PID"
    else
        echo "ERROR: LIMA failed to start (process exited immediately)"
        echo "Check the logs above for error messages"
        LIMA_PID=""
    fi
fi

echo ""
if [ -n "$LIMA_PID" ]; then
    echo "Both systems are running. Press Ctrl+C to stop."
else
    echo "ROS is running (LIMA failed to start). Press Ctrl+C to stop."
fi
echo ""

# Wait for processes
if [ -n "$LIMA_PID" ]; then
    wait $ROS_PID $LIMA_PID 2>/dev/null || true
else
    wait $ROS_PID 2>/dev/null || true
fi
