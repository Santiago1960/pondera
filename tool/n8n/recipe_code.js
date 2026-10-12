// Code in JavaScript node. Authorization inputs and response envelope are unchanged.
const agent = $('AI Agent').item.json;
const request = $('Validate request').item.json.request;
const authorized = $('Validate authorization').item.json.response;
const fail = (http, reasonCode, message, retryable = false) => ({
  json: {
    http,
    response: {
      schema_version: 1,
      request_id: request.request_id,
      decision: 'error',
      access_status: authorized.access_status,
      reason_code: reasonCode,
      server_time: new Date().toISOString(),
      message,
      recipe_action: 'keep',
      ...(retryable ? { retryable: true } : {})
    }
  }
});
const normalize = value => value.replace(',', '.');
const sample = request.trama;
const expected = request.valor_esperado.trim();
// 1. The expected sample, rather than the frame's first byte, defines its sign.
const isNegative = expected.startsWith('-');
const magnitude = Math.abs(Number(normalize(expected)));
// 2. Locate unsigned magnitudes, independently of labels, controls or signs.
const tokens = [...sample.matchAll(/[0-9]+(?:[.,][0-9]+)?/g)];
const candidates = tokens.filter(t => Number(normalize(t[0])) === magnitude);
const failure = (stage, message) => {
  const result = fail(400, 'invalid_request', message + ' La receta actual no fue modificada.');
  result.json.diagnostic = { validation_stage: stage };
  return result;
};
if (candidates.length === 0) return failure('magnitude',
  'El valor esperado no aparece en la muestra capturada. Usa el peso de esa muestra, no una lectura posterior del indicador.');

// The AI supplies a location hint when the same magnitude occurs in several fields.
// Its full-frame anchors and metadata are never carried into the resulting recipe.
let candidate = null;
let hint = null;
try {
  let output = agent.error ? null : agent.output;
  if (typeof output === 'string') {
    const start = output.indexOf('{');
    const end = output.lastIndexOf('}');
    output = start >= 0 && end > start ? JSON.parse(output.slice(start, end + 1)) : null;
  }
  candidate = typeof output?.regex_pattern === 'string' ? output.regex_pattern : null;
  if (candidate) {
    const found = [...sample.matchAll(new RegExp(candidate, 'gd'))];
    if (found.length === 1) {
      const match = found[0];
      const range = match.indices.groups?.weight ?? match.indices[1];
      const target = range && candidates.find(t => t.index >= range[0] && t.index + t[0].length <= range[1]);
      const signRange = match.indices.groups?.sign;
      if (target) hint = { target, signIndex: match.groups?.sign === '-' ? signRange?.[0] : null };
    }
  }
} catch (_) {
  // Magnitude/sign discovery also works when the model's output is unusable.
}

// 3. Only a negative expected sample requires locating a minus sign in the frame.
const minusPositions = isNegative ? [...sample.matchAll(/-/g)].map(m => m.index) : [];
if (isNegative && minusPositions.length === 0) return failure('sign',
  'La muestra es negativa, pero no se encontró el signo menos dentro de la trama.');
const distance = (position, token) => position < token.index
  ? token.index - position : position - token.index - token[0].length + 1;
let target = hint?.target;
if (!target) {
  const decimalCandidates = candidates.filter(t => /[.,]/.test(t[0]));
  const available = decimalCandidates.length ? decimalCandidates : candidates;
  target = isNegative
    ? available.reduce((best, token) => Math.min(...minusPositions.map(p => distance(p, token))) <
      Math.min(...minusPositions.map(p => distance(p, best))) ? token : best)
    : available[0];
}
const signIndex = !isNegative ? null : minusPositions.includes(hint?.signIndex)
  ? hint.signIndex : minusPositions.reduce((best, position) => distance(position, target) < distance(best, target) ? position : best);

// 4. Build a recipe for the selected field and its sign. Retain adjacent context
// only to distinguish numeric fields; envelope bytes, header fields and line endings
// outside the weight/sign span are irrelevant to extraction.
const magnitudePattern = text => {
  const decimal = text.search(/[.,]/);
  return decimal < 0 ? '[0-9]+' : '[0-9]+' +
    (text[decimal] === '.' ? '\\.' : ',') + '[0-9]{' + (text.length - decimal - 1) + '}';
};
const literal = text => text.replace(/[\\^$.*+?()[\]{}|]/g, '\\$&')
  .replace(/[ \t]+/g, '[ \\t]*')
  .replace(/[\x00-\x1f\x7f]/g, c => '\\x' + c.charCodeAt(0).toString(16).padStart(2, '0'));
const weightStart = target.index;
const weightEnd = weightStart + target[0].length;
const spanStart = signIndex == null ? weightStart : Math.min(weightStart, signIndex);
const spanEnd = signIndex == null ? weightEnd : Math.max(weightEnd, signIndex + 1);
const previous = tokens.filter(t => t.index + t[0].length <= spanStart).pop();
const next = tokens.find(t => t.index >= spanEnd);
let start = tokens.length === 1 ? spanStart : previous ? previous.index + previous[0].length : 0;
let end = next ? next.index : sample.length;
for (let i = start; i < spanStart; i++) {
  if (/[\x00-\x1f\x7f]/.test(sample[i])) start = i + 1;
}
while (start < spanStart && /[ \t]/.test(sample[start])) start++;
if (!isNegative && (sample[start] === '+' || sample[start] === '-')) {
  start++;
  while (start < spanStart && /[ \t]/.test(sample[start])) start++;
}
for (let i = spanEnd; i < end; i++) {
  if (/[\x00-\x1f\x7f]/.test(sample[i])) { end = i; break; }
}
while (end > spanEnd && /[ \t]/.test(sample[end - 1])) end--;
const replacements = tokens.filter(t => t.index >= start && t.index + t[0].length <= end).map(t => ({
  start: t.index,
  end: t.index + t[0].length,
  value: t === target
    ? '(?<![0-9.,])(?<weight>' + magnitudePattern(t[0]) + ')(?![0-9.,])'
    : magnitudePattern(t[0]),
}));
if (isNegative) replacements.push({ start: signIndex, end: signIndex + 1, value: '(?<sign>[+-]?)[ \\t]*' });
else {
  // A positive sample captures only magnitude, even with an inline display sign.
  const inlineSign = /[+-][ \t]*$/.exec(sample.slice(start, weightStart));
  if (inlineSign) replacements.push({
    start: start + inlineSign.index,
    end: weightStart,
    value: '[+-]?[ \\t]*',
  });
}
replacements.sort((a, b) => a.start - b.start);
let cursor = start;
let pattern = '';
for (const replacement of replacements) {
  pattern += literal(sample.slice(cursor, replacement.start)) + replacement.value;
  cursor = replacement.end;
}
pattern += literal(sample.slice(cursor, end));
const verification = [...sample.matchAll(new RegExp(pattern, 'gd'))];
if (verification.length !== 1 || verification[0].indices.groups.weight[0] !== weightStart ||
  Number(normalize((verification[0].groups.sign ?? '') + verification[0].groups.weight)) !== Number(normalize(expected))) {
  return failure('extraction', 'No se pudo aislar el peso y su signo dentro de la trama.');
}
return {
  json: {
    http: 200,
    response: {
      ...authorized,
      recipe_id: 'RECIPE-' + request.request_id.slice(4),
      regex_pattern: pattern
    }
  }
};
