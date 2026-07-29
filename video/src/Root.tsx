import React from "react";
import { Composition } from "remotion";
import { Commercial } from "./Commercial";
import timing from "./timing.json";

export const Root: React.FC = () => (
  <Composition
    id="Commercial"
    component={Commercial}
    durationInFrames={timing.total}
    fps={30}
    width={1920}
    height={1080}
  />
);
