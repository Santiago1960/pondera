const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const code = fs.readFileSync(path.join(__dirname, 'recipe_code.js'), 'utf8');
const run = new Function('$', code);
const authorized = {schema_version: 1, request_id: 'RAC-test', decision: 'allow',
  access_status: 'licensed', recipe_action: 'replace', reason_code: 'license_valid',
  confirmed_license_id: 'test-license', server_time: '2026-09-13T00:00:00.000Z', message: 'Receta generada.'};
function generate(trama, valor_esperado, candidate, error = false) {
  const data = {
    'AI Agent': {output: typeof candidate === 'object' && candidate !== null ? candidate : JSON.stringify({regex_pattern: candidate}), error},
    'Validate request': {request: {request_id: 'RAC-test', trama, valor_esperado}},
    'Validate authorization': {response: authorized},
  };
  return run(name => ({item: {json: data[name]}})).json;
}
function extract(regex, frame) {
  const match = regex.exec(frame);
  assert.ok(match, `No weight extracted from ${JSON.stringify(frame)}`);
  return (match.groups.sign ?? '') + match.groups.weight;
}
test('execution 1591: isolates GI-410 weight without requiring the frame terminator', () => {
  const candidate = String.raw`^\x02[0-9]+[ \t]+[0-9]+[ \t]+(?<sign>[+-]?)[ \t]*B[ \t]+(?<weight>[0-9]+,[0-9]{2})T[ \t]+[0-9]+,[0-9]{2}N[ \t]+[0-9]+,[0-9]{2}[ \t]*\x03\r\n$`;
  const result = generate('\x020001 000000  -B  0,20T  0,00N  0,20 \x03\r\n', '-0.20', candidate);
  assert.equal(result.http, 200);
  for (const frame of [
    '\x020001 000000   B  0,38T  0,00N  0,38',
    '\x020001 000000   B  0,38T  0,00N  0,38 \x03\r\n',
    'B  0,38T  0,00N  0,38',
  ]) {
    const match = new RegExp(result.response.regex_pattern).exec(frame);
    assert.ok(match, 'The recipe must isolate weight and sign, not require all frame metadata');
    assert.equal(match.groups.weight, '0,38');
    assert.equal(match.groups.sign, '');
  }
});
test('positive BR-15 samples isolate unsigned magnitude, units and leading zeros', () => {
  for (const candidate of [
    String.raw`^([+-]?[0-9]+\.[0-9]{3})kg$`,
    String.raw`^(?<full_weight>[+-]?[0-9]+\.[0-9]{3})kg$`,
    String.raw`^(?<sign>[+-]?)(?<weight>[0-9]+\.[0-9]{3})kg$`,
  ]) {
    const result = generate('+000.562kg', '0.562', candidate);
    assert.equal(result.http, 200);
    for (const weight of ['+000.562', '000.562', '+000.000', '+12345.678']) {
      const regex = new RegExp(result.response.regex_pattern);
      assert.equal(extract(regex, weight + 'kg'), weight.replace(/^\+/, ''));
      assert.equal(regex.exec(weight + 'kg').groups.sign, undefined);
    }
    for (const wrong of ['+000,562kg', '+000.5627kg', '+000.56kg', '+000.562lb']) {
      assert.equal(new RegExp(result.response.regex_pattern).exec(wrong), null);
    }
  }
});

test('BR-15 reports a changed sample value instead of blaming its format or sign', () => {
  const candidate = String.raw`^(?<full_weight>[+-]?[0-9]+\.[0-9]{3})kg$`;
  const result = generate('+000.563kg', '0.561', candidate);
  assert.equal(result.http, 400);
  assert.equal(result.response.recipe_action, 'keep');
  assert.match(result.response.message, /valor esperado.*muestra capturada/i);
  assert.equal(result.diagnostic.validation_stage, 'magnitude');
  assert.equal(generate('+000.563kg', '0.563', candidate).http, 200);
});

test('GI-410 replaces the negative sign with padding when its weight becomes positive', () => {
  const negative = '\x020001 000000  -B  0,20T  0,00N  0,20';
  const positive = '\x020001 000000   B  0,38T  0,00N  0,38';
  const candidate = String.raw`^\x02[0-9]{4} [0-9]{6}  (?<sign>[+-]?)B  (?<weight>[0-9]+,[0-9]{2})T  [+-]?[0-9]+,[0-9]{2}N  [+-]?[0-9]+,[0-9]{2}$`;
  const result = generate(negative, '-0.20', candidate);
  assert.equal(result.http, 200);
  const regex = new RegExp(result.response.regex_pattern);
  for (const [frame, sign, weight] of [
    [negative, '-', '0,20'],
    [positive, '', '0,38'],
    [positive.replace('0,38', '0,00'), '', '0,00'],
    [positive.replace('   B  0,38', '  +B  12345,67'), '+', '12345,67'],
  ]) {
    const match = regex.exec(frame);
    assert.ok(match, 'The validated recipe must match the changed sign padding');
    assert.equal(match.groups.sign, sign);
    assert.equal(match.groups.weight, weight);
  }
});

test('BR-15 can recover invalid AI output without changing other frame layouts', () => {
  for (const frame of ['+000.562kg', '+000.562kg\r\n', '\x02+000.562kg\x03']) {
    for (const candidate of [null, String.raw`B ([0-9]+,[0-9]{2})T`, String.raw`^\+([0-9]+\.[0-9]{3})kg$`]) {
      const result = generate(frame, '0,562', candidate);
      assert.equal(result.http, 200);
      const regex = new RegExp(result.response.regex_pattern);
      assert.equal(extract(regex, frame), '000.562');
      assert.equal(extract(regex, frame.replace('+000.562', '+12345.678')), '12345.678');
      assert.equal(extract(regex, frame.replace('+000.562', '000.000')), '000.000');
    }
  }
});

test('numeric formats preserve separator and precision; authorization is unchanged', () => {
  for (const value of ['0,16', '0.160', '16']) {
    const result = generate(value, value, null);
    assert.equal(result.http, 200);
    for (const [key, value] of Object.entries(authorized)) assert.equal(result.response[key], value);
    const regex = new RegExp(result.response.regex_pattern);
    assert.equal(regex.exec(value)[1], value);
    assert.equal(regex.exec('12345' + value.slice(value.search(/[.,]/) < 0 ? value.length : value.search(/[.,]/)))[1].startsWith('12345'), true);
  }
});
test('overfitted laptop recipe is replaced and handles changing numeric context', () => {
  const result = generate('\x020001 000000 B 0,30T 0,00N 0,16', '0,16',
    String.raw`\sB\s+0,30T\s+0,00N\s+([0-9]+,[0-9]+)`);
  assert.equal(result.http, 200);
  const regex = new RegExp(result.response.regex_pattern);
  assert.equal(regex.exec('\x020017 000005 B 1,25T 0,10N 12345,67')[1], '12345,67');
  assert.equal(regex.exec('\x020017 000005 B 1,25T 0,10N 12345.67'), null);
  assert.equal(regex.exec('\x020017 000005 B 1,25T 0,10N 12345,678'), null);
});
test('AI field selection is preserved while external numeric metadata can change', () => {
  const candidate = String.raw`B\s+([+-]?[0-9]+,[0-9]{2})T`;
  const result = generate('B 0,16T 0,00N 0,20', '0,16', candidate);
  assert.equal(result.http, 200);
  const regex = new RegExp(result.response.regex_pattern);
  assert.equal(extract(regex, 'metadata B 12345,67T 9,99N 6,00 trailer'), '12345,67');
  assert.equal(regex.exec('B 0.16T 0,00N 0,20'), null);
});
test('repeated expected value accepts whichever occurrence the recipe identifies', () => {
  const frame = 'B 0,16T 0,00N 0,16';
  const first = generate(frame, '0,16', String.raw`B\s+([0-9]+,[0-9]{2})T`);
  assert.equal(first.http, 200);
  assert.equal(extract(new RegExp(first.response.regex_pattern), 'B 1,25T 0,00N 2,50'), '1,25');
  const second = generate(frame, '0,16', String.raw`N\s+([0-9]+,[0-9]{2})$`);
  assert.equal(second.http, 200);
  assert.equal(extract(new RegExp(second.response.regex_pattern), 'B 1,25T 0,00N 2,50'), '2,50');
});
test('missing weight is actionable and model failure can use structural fallback', () => {
  assert.equal(generate('A 0,20', '0,16', null).http, 400);
  assert.equal(generate('A 0,16', '0,16', null, true).http, 200);
});

test('negative samples generate recipes that capture signs across zero', () => {
  for (const sample of ['-0.20', '-0,20', '-20']) {
    const result = generate('B ' + sample + 'T 0N', sample.replace(',', '.'), null);
    assert.equal(result.http, 200);
    const regex = new RegExp(result.response.regex_pattern);
    const suffix = sample.includes('.') ? '.20' : sample.includes(',') ? ',20' : '';
    for (const weight of [sample, '0' + suffix, '12345' + suffix, '-12345' + suffix, '+12345' + suffix]) {
      assert.equal(extract(regex, 'B ' + weight + 'T 0N'), weight);
    }
  }
});

test('candidate that fixes or omits the sign is replaced', () => {
  for (const candidate of [String.raw`B -([0-9]+\.[0-9]{2})T`, String.raw`B (-[0-9]+\.[0-9]{2})T`]) {
    const result = generate('B -0.20T', '-0.20', candidate);
    assert.equal(result.http, 200);
    const regex = new RegExp(result.response.regex_pattern);
    assert.equal(extract(regex, 'B -0.20T'), '-0.20');
    assert.equal(extract(regex, 'B 0.20T'), '0.20');
  }
});

test('model locates separated signs before or after weight in different layouts', () => {
  for (const [frame, candidate, changed] of [
    ['0001 000000 -B 0,20T 0,00N 0,20', String.raw`^[0-9]+ [0-9]+ (?<sign>[+-]?)B (?<weight>[0-9]+,[0-9]{2})T [0-9]+,[0-9]{2}N [0-9]+,[0-9]{2}$`, '0002 000001 +B 1,25T 0,10N 0,15'],
    ['W=0.20;S=-', String.raw`^W=(?<weight>[0-9]+\.[0-9]{2});S=(?<sign>[+-]?)$`, 'W=1.25;S=+'],
  ]) {
    const result = generate(frame, '-0.20', candidate);
    assert.equal(result.http, 200);
    const groups = new RegExp(result.response.regex_pattern).exec(changed).groups;
    assert.equal(groups.sign, '+');
    assert.equal(Number(groups.weight.replace(',', '.')), 1.25);
  }
});

test('negative expected sample locates a separated minus independently of AI output', () => {
  const frame = '-B 0,20T';
  for (const candidate of [null, String.raw`(?<sign>-)B (?<weight>[0-9]+,[0-9]{2})T`]) {
    const result = generate(frame, '-0.20', candidate);
    assert.equal(result.http, 200);
    const regex = new RegExp(result.response.regex_pattern);
    assert.equal(extract(regex, frame), '-0,20');
    assert.equal(extract(regex, ' B 1,25T'), '1,25');
    assert.equal(extract(regex, '+B 1,25T'), '+1,25');
  }
});

test('structured agent output works and failures identify the validation stage', () => {
  const pattern = String.raw`^(?<sign>[+-]?)B (?<weight>[0-9]+,[0-9]{2})T$`;
  assert.equal(generate('-B 0,20T', '-0.20', {regex_pattern: pattern}).http, 200);
  assert.equal(generate('-B 0,20T', '-0.20', null).http, 200);
  const missingMagnitude = generate('-B 0,25T', '-0.20', null);
  assert.equal(missingMagnitude.diagnostic.validation_stage, 'magnitude');
  assert.equal(missingMagnitude.response.recipe_action, 'keep');
  const missingSign = generate('B 0,20T', '-0.20', {regex_pattern: pattern});
  assert.equal(missingSign.diagnostic.validation_stage, 'sign');
  assert.equal(missingSign.response.recipe_action, 'keep');
});

test('envelope controls are optional and labels distinguish the selected field', () => {
  const frame = '\x020001 000000  -B  0,20T  0,00N  0,20\x03\r\n';
  const pattern = String.raw`^\x02[0-9]{4}[ \t]+[0-9]{6}[ \t]+(?<sign>[+-]?)[ \t]*B[ \t]+(?<weight>[0-9]+,[0-9]{2})T[ \t]+[+-]?[0-9]+,[0-9]{2}N[ \t]+[+-]?[0-9]+,[0-9]{2}\x03\r\n$`;
  const result = generate(frame, '-0.20', pattern);
  assert.equal(result.http, 200);
  const regex = new RegExp(result.response.regex_pattern);
  for (const sign of ['', '+', '-']) {
    const changed = frame.replace('-B  0,20', sign + 'B  0,00');
    const groups = regex.exec(changed).groups;
    assert.equal(groups.sign, sign);
    assert.equal(groups.weight, '0,00');
    assert.equal(extract(regex, changed.slice(1, -3)), sign + '0,00');
  }
  const missingLabels = String.raw`^\x02[0-9]{4}\s+[0-9]{6}\s+(?:[+-]?[0-9]+,[0-9]{2})\s+(?:[+-]?[0-9]+,[0-9]{2})\s+([+-]?[0-9]+,[0-9]{2})\x03\r\n$`;
  const recovered = generate(frame, '-0.20', missingLabels);
  assert.equal(recovered.http, 200);
  assert.equal(extract(new RegExp(recovered.response.regex_pattern), '-B  1,25T  0,00N  6,00'), '-1,25');
});

test('positive expected samples do not require finding or capturing a sign', () => {
  for (const frame of ['B 0.00T 2N', 'B +0.00T 2N']) {
    const result = generate(frame, '0.00', null);
    assert.equal(result.http, 200);
    const regex = new RegExp(result.response.regex_pattern);
    assert.equal(extract(regex, frame.replace('0.00', '123.45')), '123.45');
    assert.equal(regex.exec(frame).groups.sign, undefined);
  }
  const result = generate('firmware-V2 B 0,20T 7N', '0.20', null);
  assert.equal(result.http, 200);
  assert.equal(extract(new RegExp(result.response.regex_pattern), 'firmware-V9 B 1,25T 9N'), '1,25');
});

test('negative samples locate signs across arbitrary literal characters in either direction', () => {
  for (const [frame, changed] of [
    ['-Q:@[ 0,45X 8,10', ' Q:@[ 123,45X 0,00'],
    ['0.45;SIGN={-}', '123.45;SIGN={ }'],
    ['-Q\x010.45!', '+Q\x01123.45!'],
  ]) {
    const result = generate(frame, '-0.45', null);
    assert.equal(result.http, 200);
    const regex = new RegExp(result.response.regex_pattern);
    assert.equal(Number(extract(regex, frame).replace(',', '.')), -0.45);
    assert.equal(Number(extract(regex, changed).replace(',', '.')), 123.45);
  }
});

test('numeric boundaries prevent partial captures of unsupported precision or separator', () => {
  const result = generate('0,20', '0.20', null);
  assert.equal(result.http, 200);
  const regex = new RegExp(result.response.regex_pattern);
  assert.equal(extract(regex, '12345,67'), '12345,67');
  for (const wrong of ['0,200', '0,2', '0.20', '1.000,20', '0,20.00']) {
    assert.equal(regex.exec(wrong), null);
  }
});
