import React from 'react';
import Svg, { Circle, Path } from 'react-native-svg';
import { palette } from '../theme';

/** MindSpeak brain-circuit mark. */
export function BrainLogo({ size = 64, color = palette.primary, accent = palette.secondary }: { size?: number; color?: string; accent?: string }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 100 100" fill="none">
      <Path
        d="M50 16 C40 9 26 13 24 26 C14 28 9 42 17 50 C9 58 13 72 26 74 C30 85 44 87 50 82 Z"
        stroke={color}
        strokeWidth={4}
        strokeLinejoin="round"
        strokeLinecap="round"
      />
      <Path
        d="M50 16 C60 9 74 13 76 26 C86 28 91 42 83 50 C91 58 87 72 74 74 C70 85 56 87 50 82 Z"
        stroke={color}
        strokeWidth={4}
        strokeLinejoin="round"
        strokeLinecap="round"
      />
      <Path d="M50 34 H39 C33 34 31 40 35 44" stroke={accent} strokeWidth={3.5} strokeLinecap="round" />
      <Path d="M50 56 H37 C31 56 29 62 33 66" stroke={accent} strokeWidth={3.5} strokeLinecap="round" />
      <Path d="M50 34 H61 C67 34 69 40 65 44" stroke={accent} strokeWidth={3.5} strokeLinecap="round" />
      <Path d="M50 56 H63 C69 56 71 62 67 66" stroke={accent} strokeWidth={3.5} strokeLinecap="round" />
      <Circle cx={35} cy={44} r={3} fill={accent} />
      <Circle cx={33} cy={66} r={3} fill={accent} />
      <Circle cx={65} cy={44} r={3} fill={accent} />
      <Circle cx={67} cy={66} r={3} fill={accent} />
    </Svg>
  );
}
