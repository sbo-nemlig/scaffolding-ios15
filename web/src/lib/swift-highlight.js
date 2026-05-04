// Tiny Swift-flavored tokenizer.
// Output is HTML with <span class="..."> wrappers.
// Black-and-white only — distinctions live in CSS via weight + opacity.

const KEYWORDS = new Set([
  'associatedtype', 'async', 'await', 'borrowing', 'break', 'case', 'catch',
  'class', 'consuming', 'continue', 'default', 'defer', 'deinit', 'do', 'else',
  'enum', 'extension', 'fallthrough', 'fileprivate', 'final', 'for', 'func',
  'guard', 'if', 'import', 'in', 'indirect', 'init', 'inout', 'internal', 'is',
  'lazy', 'let', 'mutating', 'nonisolated', 'open', 'operator', 'override',
  'package', 'precedencegroup', 'private', 'protocol', 'public', 'repeat',
  'rethrows', 'return', 'set', 'static', 'struct', 'subscript', 'switch',
  'throw', 'throws', 'try', 'typealias', 'var', 'where', 'while',
  'as', 'Any', 'some', 'any', 'self', 'Self', 'super',
  'true', 'false', 'nil',
  'get', 'didSet', 'willSet'
]);

const BUILTIN_TYPES = new Set([
  'Int', 'Int8', 'Int16', 'Int32', 'Int64',
  'UInt', 'UInt8', 'UInt16', 'UInt32', 'UInt64',
  'Float', 'Double', 'Bool', 'Character', 'String', 'StaticString',
  'Array', 'Dictionary', 'Set', 'Optional', 'Result', 'Range', 'ClosedRange',
  'Void', 'Never', 'Error', 'Equatable', 'Hashable', 'Comparable',
  'Sendable', 'Identifiable', 'Codable', 'Encodable', 'Decodable',
  'AnyObject', 'AnyHashable',
  'View', 'AnyView', 'EmptyView', 'Text', 'Button', 'Label', 'List',
  'NavigationStack', 'TabView', 'Tab', 'Image', 'Form', 'Section',
  'Binding', 'State', 'Environment', 'Observable', 'MainActor',
  'UUID'
]);

const ESC_RE = /[&<>]/g;
const ESC_MAP = { '&': '&amp;', '<': '&lt;', '>': '&gt;' };
function escape(s) {
  return s.replace(ESC_RE, (c) => ESC_MAP[c]);
}

function span(cls, text) {
  return `<span class="${cls}">${escape(text)}</span>`;
}

function isIdStart(c) {
  return /[A-Za-z_]/.test(c);
}
function isIdCont(c) {
  return /[A-Za-z0-9_]/.test(c);
}

// Operator characters per Swift reference (subset that appears in samples).
const OP_CHARS = new Set(['+', '-', '*', '/', '%', '=', '<', '>', '!', '&', '|', '^', '~', '?', '.']);

/**
 * Tokenize and emit HTML.
 * Recursion is used for string interpolation: \( ... ) inside a literal
 * is tokenized as code so calls and types stay highlighted.
 */
export function highlight(src) {
  let i = 0;
  const n = src.length;
  let out = '';

  // Lookahead helpers, so we can emit `fn` for `name(` and `lab` for `label:`.
  function peekNonSpace(from) {
    let j = from;
    while (j < n && /[ \t]/.test(src[j])) j++;
    return src[j] ?? '';
  }

  function readBlockComment(start) {
    let depth = 1;
    let j = start + 2;
    while (j < n && depth > 0) {
      if (src[j] === '/' && src[j + 1] === '*') { depth++; j += 2; }
      else if (src[j] === '*' && src[j + 1] === '/') { depth--; j += 2; }
      else j++;
    }
    return j;
  }

  function readString(start) {
    // Returns the rendered HTML for a string literal starting at `start`,
    // and the index after the closing quote. Handles escapes and \( ... ).
    let j = start + 1;
    let buf = '"';
    let html = '';
    const flushBuf = () => {
      if (buf) { html += span('str', buf); buf = ''; }
    };
    while (j < n) {
      const c = src[j];
      if (c === '\\') {
        const next = src[j + 1];
        if (next === '(') {
          // Interpolation: tokenize the inner expression as code.
          flushBuf();
          html += span('punc', '\\(');
          j += 2;
          let depth = 1;
          let exprStart = j;
          while (j < n && depth > 0) {
            const ec = src[j];
            if (ec === '(') depth++;
            else if (ec === ')') depth--;
            else if (ec === '"') {
              // Skip nested string fully (cheap version, no inner highlight).
              j++;
              while (j < n && src[j] !== '"') {
                if (src[j] === '\\' && j + 1 < n) j += 2;
                else j++;
              }
            }
            if (depth > 0) j++;
          }
          const inner = src.slice(exprStart, j);
          html += highlight(inner);
          if (src[j] === ')') {
            html += span('punc', ')');
            j++;
          }
          continue;
        } else {
          // Generic escape: \\, \n, \t, \", etc.
          buf += src.slice(j, j + 2);
          j += 2;
          continue;
        }
      }
      if (c === '"') {
        buf += '"';
        flushBuf();
        return { html, end: j + 1 };
      }
      buf += c;
      j++;
    }
    // Unterminated: emit what we have.
    flushBuf();
    return { html, end: n };
  }

  function readNumber(start) {
    let j = start;
    if (src[j] === '0' && (src[j + 1] === 'x' || src[j + 1] === 'X')) {
      j += 2;
      while (j < n && /[0-9A-Fa-f_]/.test(src[j])) j++;
    } else if (src[j] === '0' && (src[j + 1] === 'b' || src[j + 1] === 'B')) {
      j += 2;
      while (j < n && /[01_]/.test(src[j])) j++;
    } else if (src[j] === '0' && (src[j + 1] === 'o' || src[j + 1] === 'O')) {
      j += 2;
      while (j < n && /[0-7_]/.test(src[j])) j++;
    } else {
      while (j < n && /[0-9_]/.test(src[j])) j++;
      if (src[j] === '.' && /[0-9]/.test(src[j + 1] ?? '')) {
        j++;
        while (j < n && /[0-9_]/.test(src[j])) j++;
      }
      if (src[j] === 'e' || src[j] === 'E') {
        j++;
        if (src[j] === '+' || src[j] === '-') j++;
        while (j < n && /[0-9_]/.test(src[j])) j++;
      }
    }
    return j;
  }

  while (i < n) {
    const c = src[i];
    const c2 = src[i + 1];

    // Block comment (nested-aware).
    if (c === '/' && c2 === '*') {
      const end = readBlockComment(i);
      out += span('cmt', src.slice(i, end));
      i = end;
      continue;
    }

    // Line comment.
    if (c === '/' && c2 === '/') {
      let j = src.indexOf('\n', i);
      if (j === -1) j = n;
      out += span('cmt', src.slice(i, j));
      i = j;
      continue;
    }

    // String.
    if (c === '"') {
      const { html, end } = readString(i);
      out += html;
      i = end;
      continue;
    }

    // Attribute.
    if (c === '@') {
      let j = i + 1;
      while (j < n && isIdCont(src[j])) j++;
      out += span('att', src.slice(i, j));
      i = j;
      continue;
    }

    // Number.
    if (/[0-9]/.test(c)) {
      const end = readNumber(i);
      out += span('num', src.slice(i, end));
      i = end;
      continue;
    }

    // Identifier / keyword / type / function call / parameter label.
    if (isIdStart(c)) {
      let j = i;
      while (j < n && isIdCont(src[j])) j++;
      const word = src.slice(i, j);

      let cls;
      if (KEYWORDS.has(word)) {
        cls = 'kw';
      } else if (BUILTIN_TYPES.has(word) || /^[A-Z]/.test(word)) {
        cls = 'ty';
      } else {
        // Function call: name immediately followed by `(` or `<…>(`.
        const next = peekNonSpace(j);
        const prevNonSpace = (() => {
          let k = i - 1;
          while (k >= 0 && /\s/.test(src[k])) k--;
          return src[k] ?? '';
        })();
        if (next === '(') {
          cls = prevNonSpace === '.' ? 'mem' : 'fn';
        } else if (next === ':' && /[(,]/.test(prevNonSpace)) {
          // Parameter label inside a call argument list.
          cls = 'lab';
        } else if (prevNonSpace === '.') {
          // Member or enum case access.
          cls = 'mem';
        } else {
          cls = 'id';
        }
      }
      out += span(cls, word);
      i = j;
      continue;
    }

    // Operator run.
    if (OP_CHARS.has(c)) {
      let j = i;
      while (j < n && OP_CHARS.has(src[j])) j++;
      // Render as plain punctuation; keeps things visually quiet.
      out += span('op', src.slice(i, j));
      i = j;
      continue;
    }

    // Anything else: brackets, commas, whitespace.
    out += escape(c);
    i++;
  }

  return out;
}
