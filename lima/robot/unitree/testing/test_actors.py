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
import asyncio
from collections.abc import Callable

import pytest

from lima.core.core import rpc
from lima.core.module import Module
from lima.core.module_coordinator import ModuleCoordinator
from lima.core.transport import LCMTransport
from lima.msgs.sensor_msgs import PointCloud2
from lima.robot.unitree.type.map import Map as Mapper


@pytest.fixture
def lima():
    ret = ModuleCoordinator()
    ret.start()
    try:
        yield ret
    finally:
        ret.stop()


class Consumer:
    testf: Callable[[int], int]

    def __init__(self, counter=None) -> None:
        self.testf = counter
        self._tasks: set[asyncio.Task[None]] = set()
        print("consumer init with", counter)

    async def waitcall(self, n: int):
        async def task() -> None:
            await asyncio.sleep(n)

            print("sleep finished, calling")
            res = await self.testf(n)
            print("res is", res)

        background_task = asyncio.create_task(task())
        self._tasks.add(background_task)
        background_task.add_done_callback(self._tasks.discard)
        return n


class Counter(Module):
    @rpc
    def addten(self, x: int):
        print(f"counter adding to {x}")
        return x + 10


@pytest.mark.tool
def test_basic(lima) -> None:
    counter = lima.deploy(Counter)
    consumer = lima.deploy(
        Consumer,
        counter=lambda x: counter.addten(x).result(),
    )

    print(consumer)
    print(counter)
    print("starting consumer")
    consumer.start().result()

    res = consumer.inc(10).result()

    print("result is", res)
    assert res == 20


@pytest.mark.tool
def test_mapper_start(lima) -> None:
    mapper = lima.deploy(Mapper)
    mapper.lidar.transport = LCMTransport("/lidar", PointCloud2)
    print("start res", mapper.start().result())


@pytest.mark.tool
def test_counter(lima) -> None:
    counter = lima.deploy(Counter)
    assert counter.addten(10) == 20
