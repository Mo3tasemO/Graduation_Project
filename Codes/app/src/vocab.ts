import { palette } from './theme';

export type Word = { label: string; icon: string; color: string; say?: string };

const red = palette.error;
const blue = palette.primary;
const cyan = palette.secondary;
const green = palette.success;
const amber = palette.warning;
const purple = palette.purple;

const W = {
  pain: { label: 'Pain', icon: 'bandage', color: red, say: 'I am in pain' },
  medicine: { label: 'Medicine', icon: 'pill', color: blue, say: 'I need my medicine' },
  doctor: { label: 'Doctor', icon: 'stethoscope', color: cyan, say: 'Please call the doctor' },
  water: { label: 'Water', icon: 'water', color: blue, say: 'I need water' },
  food: { label: 'Food', icon: 'food-apple', color: red, say: 'I am hungry' },
  drink: { label: 'Drink', icon: 'cup-water', color: green, say: 'I want a drink' },
  help: { label: 'Help', icon: 'alarm-light', color: red, say: 'Help me' },
  yes: { label: 'Yes', icon: 'check-circle', color: green, say: 'Yes' },
  no: { label: 'No', icon: 'close-circle', color: purple, say: 'No' },
  coffee: { label: 'Coffee', icon: 'coffee', color: amber, say: 'I would like coffee' },
  tea: { label: 'Tea', icon: 'tea', color: green, say: 'I would like tea' },
  hungry: { label: 'Hungry', icon: 'silverware-fork-knife', color: red, say: 'I am hungry' },
  thirsty: { label: 'Thirsty', icon: 'water-outline', color: cyan, say: 'I am thirsty' },
  fruit: { label: 'Fruit', icon: 'fruit-cherries', color: red, say: 'I want some fruit' },
  bread: { label: 'Bread', icon: 'bread-slice', color: amber, say: 'I want some bread' },
  thanks: { label: 'Thank you', icon: 'hand-heart', color: purple, say: 'Thank you' },
  please: { label: 'Please', icon: 'hands-pray', color: blue, say: 'Please' },
  sorry: { label: 'Sorry', icon: 'emoticon-sad-outline', color: amber, say: 'I am sorry' },
  love: { label: 'Love', icon: 'heart', color: red, say: 'I love you' },
  happy: { label: 'Happy', icon: 'emoticon-happy-outline', color: green, say: 'I am happy' },
  sad: { label: 'Sad', icon: 'emoticon-sad', color: blue, say: 'I feel sad' },
  angry: { label: 'Angry', icon: 'emoticon-angry-outline', color: red, say: 'I am angry' },
  hello: { label: 'Hello', icon: 'hand-wave', color: cyan, say: 'Hello' },
  goodbye: { label: 'Goodbye', icon: 'exit-run', color: purple, say: 'Goodbye' },
  home: { label: 'Home', icon: 'home', color: blue, say: 'I want to go home' },
  family: { label: 'Family', icon: 'account-group', color: green, say: 'Please call my family' },
  tv: { label: 'TV', icon: 'television', color: amber, say: 'Turn on the TV' },
  music: { label: 'Music', icon: 'music', color: purple, say: 'I want to listen to music' },
  bathroom: { label: 'Bathroom', icon: 'toilet', color: cyan, say: 'I need the bathroom' },
  sleep: { label: 'Sleep', icon: 'sleep', color: blue, say: 'I want to sleep' },
  outside: { label: 'Outside', icon: 'tree', color: green, say: 'I want to go outside' },
};

export const CATEGORIES: Record<string, Word[]> = {
  Medical: [W.pain, W.medicine, W.doctor, W.water, W.food, W.drink, W.help, W.yes, W.no],
  'Food & Water': [W.water, W.food, W.drink, W.coffee, W.tea, W.hungry, W.thirsty, W.fruit, W.bread],
  Expressive: [W.yes, W.no, W.thanks, W.please, W.sorry, W.love, W.happy, W.sad, W.angry],
  General: [W.hello, W.goodbye, W.home, W.family, W.tv, W.music, W.bathroom, W.sleep, W.outside],
};

export const QUICK = [W.help, W.yes, W.no];

/** Words the (mock) model can predict. */
export const PREDICTABLE: Word[] = [W.help, W.water, W.yes, W.no, W.pain, W.medicine, W.doctor, W.food, W.thanks, W.bathroom];

const ALL = Object.values(W);

export function wordMeta(text: string): Word {
  const t = text.toLowerCase();
  return (
    ALL.find((w) => t.includes(w.label.toLowerCase())) ??
    (t.includes('thank') ? W.thanks : undefined) ??
    { label: text, icon: 'message-text', color: palette.primary }
  );
}

export const CALIBRATION_WORDS = ['HELP', 'WATER', 'YES', 'NO', 'THANKS'];
