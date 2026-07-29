import React from "react";
import {
  AbsoluteFill,
  Audio,
  Series,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { loadFont as loadGaramond } from "@remotion/google-fonts/EBGaramond";
import { loadFont as loadInstrument } from "@remotion/google-fonts/InstrumentSans";
import timing from "./timing.json";

const garamond = loadGaramond();
const instrument = loadInstrument();

const C = {
  paper: "#faf9f7",
  deep: "#f0eeea",
  ink: "#1c1b1a",
  soft: "#5c5955",
  red: "#8a1016",
  rule: "#e2dfda",
};
const SERIF = garamond.fontFamily;
const SANS = instrument.fontFamily;

const Scene: React.FC<{ vo: string; children: React.ReactNode }> = ({ vo, children }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame, fps, config: { damping: 200 } });
  const opacity = interpolate(frame, [0, 12], [0, 1], { extrapolateRight: "clamp" });
  return (
    <AbsoluteFill
      style={{
        background: C.paper,
        alignItems: "center",
        justifyContent: "center",
        opacity,
        transform: `translateY(${(1 - enter) * 26}px)`,
      }}
    >
      <Audio src={staticFile(vo)} />
      {children}
    </AbsoluteFill>
  );
};

const Line: React.FC<{ children: React.ReactNode; size?: number }> = ({ children, size = 92 }) => (
  <div
    style={{
      fontFamily: SERIF,
      fontWeight: 500,
      fontSize: size,
      lineHeight: 1.15,
      color: C.ink,
      maxWidth: 1250,
      textAlign: "center",
    }}
  >
    {children}
  </div>
);

const S1: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame: frame - 14, fps, config: { damping: 12, stiffness: 200 } });
  return (
    <Scene vo="vo/s1.mp3">
      <div style={{ fontFamily: SANS, fontWeight: 700, fontSize: 250, letterSpacing: "-0.04em", color: C.ink }}>
        1689
        <span style={{ color: C.red, display: "inline-block", transform: `scale(${pop})` }}>.</span>
      </div>
    </Scene>
  );
};

const S2: React.FC = () => (
  <Scene vo="vo/s2.mp3">
    <Line>Every edition of the 1689 lists its scripture&nbsp;proofs.</Line>
    <div style={{ fontFamily: SANS, fontSize: 30, color: C.soft, marginTop: 48 }}>
      ( 2 Timothy 3:15–17; Isaiah 8:20; Luke 16:29, 31; Ephesians 2:20 )
    </div>
  </Scene>
);

const S3: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const cardIn = spring({ frame: frame - 55, fps, config: { damping: 16 } });
  const ring = interpolate(frame, [34, 56], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  return (
    <Scene vo="vo/s3.mp3">
      <Line>
        This one <span style={{ color: C.red }}>opens</span> them.
      </Line>
      <div style={{ fontFamily: SANS, fontSize: 30, color: C.soft, marginTop: 44, position: "relative" }}>
        ( <span style={{ color: C.red, fontWeight: 600, position: "relative" }}>
          2 Timothy 3:16
          <span
            style={{
              position: "absolute",
              left: "50%",
              top: "50%",
              width: 110,
              height: 110,
              border: `4px solid ${C.red}`,
              borderRadius: "50%",
              transform: `translate(-50%, -50%) scale(${0.3 + ring * 1.2})`,
              opacity: ring > 0 ? 1 - ring : 0,
            }}
          />
        </span>; Isaiah 8:20; Luke 16:29, 31 )
      </div>
      <div
        style={{
          background: C.deep,
          borderLeft: `6px solid ${C.red}`,
          borderRadius: 22,
          padding: "36px 44px",
          maxWidth: 1050,
          marginTop: 54,
          textAlign: "left",
          opacity: cardIn,
          transform: `translateY(${(1 - cardIn) * 40}px)`,
          boxShadow: "0 30px 80px rgba(20,18,16,.14)",
        }}
      >
        <span style={{ fontFamily: SANS, fontWeight: 700, fontSize: 21, letterSpacing: ".1em", color: C.red }}>
          BSB
        </span>
        <span style={{ fontFamily: SANS, fontWeight: 600, fontSize: 23, color: C.soft, marginLeft: 18 }}>
          2 Timothy 3:16
        </span>
        <div style={{ fontFamily: SERIF, fontSize: 37, lineHeight: 1.5, marginTop: 14, color: C.ink }}>
          All Scripture is God-breathed and is useful for instruction, for conviction, for correction, and for
          training in righteousness,
        </div>
      </div>
    </Scene>
  );
};

const S4: React.FC = () => {
  const frame = useCurrentFrame();
  const active = frame < 95 ? 0 : frame < 165 ? 1 : frame < 235 ? 2 : 3;
  const labels = ["BSB", "KJV", "WEB", "Parallel"];
  return (
    <Scene vo="vo/s4.mp3">
      <Line>In three public-domain translations.</Line>
      <div style={{ display: "flex", background: C.deep, borderRadius: 24, padding: 8, marginTop: 60 }}>
        {labels.map((l, i) => (
          <div
            key={l}
            style={{
              fontFamily: SANS,
              fontWeight: 600,
              fontSize: 34,
              padding: "20px 42px",
              borderRadius: 18,
              color: i === active ? C.paper : C.soft,
              background: i === active ? C.red : "transparent",
            }}
          >
            {l}
          </div>
        ))}
      </div>
    </Scene>
  );
};

const S5: React.FC = () => {
  const frame = useCurrentFrame();
  const q = "effectual calling";
  const typed = q.slice(0, Math.max(0, Math.floor((frame - 24) / 2.4)));
  const r1 = spring({ frame: frame - 78, fps: 30, config: { damping: 16 } });
  const r2 = spring({ frame: frame - 92, fps: 30, config: { damping: 16 } });
  const row = (s: ReturnType<typeof spring>, where: string, text: React.ReactNode) => (
    <div
      style={{
        background: "#fff",
        border: `1px solid ${C.rule}`,
        borderRadius: 18,
        padding: "22px 30px",
        marginTop: 16,
        width: 1000,
        textAlign: "left",
        opacity: s,
        transform: `translateY(${(1 - s) * 24}px)`,
      }}
    >
      <div style={{ fontFamily: SANS, fontWeight: 600, fontSize: 22, color: C.red }}>{where}</div>
      <div style={{ fontFamily: SERIF, fontSize: 28, color: C.soft, marginTop: 6 }}>{text}</div>
    </div>
  );
  return (
    <Scene vo="vo/s5.mp3">
      <Line>Search all of it.</Line>
      <div
        style={{
          width: 1000,
          background: "#fff",
          border: `1px solid ${C.rule}`,
          borderRadius: 22,
          padding: "26px 34px",
          marginTop: 56,
          textAlign: "left",
          boxShadow: "0 24px 60px rgba(20,18,16,.10)",
        }}
      >
        <span style={{ fontFamily: SANS, fontSize: 32, color: C.ink }}>{typed}</span>
        <span style={{ display: "inline-block", width: 3, height: 36, background: C.red, marginLeft: 4, verticalAlign: -6 }} />
      </div>
      {row(r1, "Chapter X · ¶ 1 — Of Effectual Calling", (
        <>…he is pleased in his appointed and accepted time <b style={{ color: C.red }}>effectually to call</b>, by his Word and Spirit…</>
      ))}
      {row(r2, "Chapter XV · ¶ 1 — Of Repentance", (
        <>…God in their <b style={{ color: C.red }}>effectual calling</b> giveth them repentance unto life.</>
      ))}
    </Scene>
  );
};

const S6: React.FC = () => {
  const frame = useCurrentFrame();
  const stats = [
    ["32", "Chapters"],
    ["770", "Scripture proofs"],
    ["3", "Translations"],
    ["0", "Ads · Accounts · Cost"],
  ];
  return (
    <Scene vo="vo/s6.mp3">
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "90px 160px" }}>
        {stats.map(([n, l], i) => {
          const s = spring({ frame: frame - 12 - i * 24, fps: 30, config: { damping: 15 } });
          return (
            <div key={l} style={{ textAlign: "center", opacity: s, transform: `translateY(${(1 - s) * 30}px)` }}>
              <div style={{ fontFamily: SERIF, fontWeight: 500, fontSize: 170, lineHeight: 1, color: C.red }}>{n}</div>
              <div
                style={{
                  fontFamily: SANS,
                  fontWeight: 600,
                  fontSize: 26,
                  letterSpacing: ".12em",
                  textTransform: "uppercase",
                  color: C.soft,
                  marginTop: 14,
                }}
              >
                {l}
              </div>
            </div>
          );
        })}
      </div>
    </Scene>
  );
};

const S7: React.FC = () => {
  const frame = useCurrentFrame();
  const url = spring({ frame: frame - 40, fps: 30, config: { damping: 200 } });
  return (
    <Scene vo="vo/s7.mp3">
      <div
        style={{
          fontFamily: SERIF,
          fontWeight: 500,
          fontSize: 128,
          lineHeight: 1.02,
          color: C.red,
          textAlign: "center",
          maxWidth: 1400,
        }}
      >
        The Baptist Confession of&nbsp;Faith
      </div>
      <div
        style={{
          fontFamily: SANS,
          fontWeight: 700,
          fontSize: 54,
          letterSpacing: "-0.02em",
          marginTop: 60,
          color: C.ink,
          opacity: url,
        }}
      >
        1689<span style={{ color: C.red }}>.</span>intentmesh<span style={{ color: C.red }}>.</span>dev
      </div>
      <div style={{ fontFamily: SANS, fontWeight: 500, fontSize: 27, color: C.soft, marginTop: 26, opacity: url }}>
        Free · No ads · No account · Public domain
      </div>
    </Scene>
  );
};

export const Commercial: React.FC = () => (
  <AbsoluteFill style={{ background: C.paper }}>
    <Series>
      <Series.Sequence durationInFrames={timing.s1}><S1 /></Series.Sequence>
      <Series.Sequence durationInFrames={timing.s2}><S2 /></Series.Sequence>
      <Series.Sequence durationInFrames={timing.s3}><S3 /></Series.Sequence>
      <Series.Sequence durationInFrames={timing.s4}><S4 /></Series.Sequence>
      <Series.Sequence durationInFrames={timing.s5}><S5 /></Series.Sequence>
      <Series.Sequence durationInFrames={timing.s6}><S6 /></Series.Sequence>
      <Series.Sequence durationInFrames={timing.s7}><S7 /></Series.Sequence>
    </Series>
  </AbsoluteFill>
);
