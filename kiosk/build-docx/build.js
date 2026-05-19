// build.js — convert kiosk/INSTALL.md into a styled .docx user manual
// that the operator can upload to Google Drive (where it converts to a
// Google Doc).
//
// Driven by `marked` for the markdown parse + `docx` for the docx-js
// document model. Output lands in ~/Downloads with a date-stamped
// filename so successive runs don't clobber each other.
//
// Not run by the kiosk itself — only run on a dev machine when the
// docs change, as part of the PR workflow.

const fs = require("fs");
const path = require("path");
const os = require("os");
const { marked } = require("marked");
const {
  Document,
  Packer,
  Paragraph,
  TextRun,
  ExternalHyperlink,
  Table,
  TableRow,
  TableCell,
  Header,
  Footer,
  Tab,
  TabStopType,
  TabStopPosition,
  PageNumber,
  PageBreak,
  AlignmentType,
  HeadingLevel,
  LevelFormat,
  BorderStyle,
  WidthType,
  ShadingType,
  VerticalAlign,
  TableOfContents,
} = require("docx");

// ----- Paths --------------------------------------------------------

const REPO_ROOT = path.resolve(__dirname, "..", "..");
const INPUT = path.join(REPO_ROOT, "kiosk", "INSTALL.md");
const DOWNLOADS = path.join(os.homedir(), "Downloads");
const stamp = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
const OUTPUT = path.join(
  DOWNLOADS,
  `Victron Exhibition Kiosk Apps — User Manual ${stamp}.docx`
);

if (!fs.existsSync(INPUT)) {
  console.error(`✖ Source missing: ${INPUT}`);
  process.exit(1);
}
if (!fs.existsSync(DOWNLOADS)) {
  console.error(`✖ Downloads folder missing: ${DOWNLOADS}`);
  process.exit(1);
}

console.log(`→ Reading  ${path.relative(REPO_ROOT, INPUT)}`);
const md = fs.readFileSync(INPUT, "utf8");

// ----- Style tokens (kept in one place so look-and-feel is easy to tweak)

const VICTRON_BLUE = "005FBE";
const TEXT_GREY = "333333";
const SUBTLE_GREY = "999999";
const CODE_BG = "F2F2F2";
const TABLE_HEADER_BG = "D5E8F0";
const TABLE_BORDER = "CCCCCC";
const QUOTE_BG = "FFF8E1"; // pale yellow — matches the warning-callout feel
const QUOTE_BORDER = "F0C040";

const BODY_FONT = "Calibri"; // universally supported by Word + Google Docs
const HEADING_FONT = "Calibri";
const MONO_FONT = "Consolas";

// US Letter @ 1" margins
const PAGE_WIDTH_DXA = 12240;
const MARGIN_DXA = 1440;
const CONTENT_WIDTH_DXA = PAGE_WIDTH_DXA - 2 * MARGIN_DXA; // 9360

// ----- Numbering reference factory ---------------------------------
//
// `marked` will give us nested lists; each level reuses one of these
// references. Two references — "bullets" and "numbers" — each with
// three indent levels (which covers everything in INSTALL.md and
// most plausible additions).
function listNumberingConfig() {
  const mkLevel = (level, format, text) => ({
    level,
    format,
    text,
    alignment: AlignmentType.LEFT,
    style: {
      paragraph: { indent: { left: 720 * (level + 1), hanging: 360 } },
    },
  });
  return [
    {
      reference: "bullets",
      levels: [
        mkLevel(0, LevelFormat.BULLET, "•"),
        mkLevel(1, LevelFormat.BULLET, "◦"),
        mkLevel(2, LevelFormat.BULLET, "▪"),
      ],
    },
    {
      reference: "numbers",
      levels: [
        mkLevel(0, LevelFormat.DECIMAL, "%1."),
        mkLevel(1, LevelFormat.LOWER_LETTER, "%2."),
        mkLevel(2, LevelFormat.LOWER_ROMAN, "%3."),
      ],
    },
  ];
}

// ----- Inline token walker -----------------------------------------
//
// Returns an array of TextRun / ExternalHyperlink instances suitable
// for a Paragraph's `children`. `baseProps` is merged into each run
// so the caller can force bold/italic/font on a whole block.
function inlineRuns(tokens, baseProps = {}) {
  const out = [];
  for (const t of tokens || []) {
    switch (t.type) {
      case "text":
        // marked nests further inline tokens inside `text.tokens` when
        // the text contains formatting (e.g. "**bold** word"). Recurse
        // when present; otherwise use the literal text.
        if (Array.isArray(t.tokens) && t.tokens.length) {
          out.push(...inlineRuns(t.tokens, baseProps));
        } else {
          out.push(new TextRun({ ...baseProps, text: decodeEntities(t.text) }));
        }
        break;

      case "strong":
        out.push(...inlineRuns(t.tokens, { ...baseProps, bold: true }));
        break;

      case "em":
        out.push(...inlineRuns(t.tokens, { ...baseProps, italics: true }));
        break;

      case "codespan":
        out.push(
          new TextRun({
            ...baseProps,
            text: decodeEntities(t.text),
            font: MONO_FONT,
            shading: { fill: CODE_BG, type: ShadingType.CLEAR },
          })
        );
        break;

      case "link": {
        // Use the hyperlink style for visible links; ExternalHyperlink
        // wraps the inner runs.
        const inner = inlineRuns(t.tokens, {
          ...baseProps,
          color: VICTRON_BLUE,
          underline: { type: "single" },
        });
        if (/^https?:\/\//i.test(t.href)) {
          out.push(new ExternalHyperlink({ children: inner, link: t.href }));
        } else {
          // Relative link → can't be a real hyperlink in a standalone
          // docx; render as styled text so the operator still sees it.
          out.push(...inner);
        }
        break;
      }

      case "br":
        // Line break inside a paragraph
        out.push(new TextRun({ ...baseProps, break: 1 }));
        break;

      case "html":
        // Strip HTML; the source uses plain HTML rarely (e.g. raw <br>).
        // Anything we don't recognise becomes literal text so it's
        // visible rather than silently lost.
        out.push(new TextRun({ ...baseProps, text: t.text.replace(/<[^>]+>/g, "") }));
        break;

      case "image":
        // INSTALL.md doesn't currently include images; emit a placeholder
        // string so a future addition is visible rather than silently
        // dropped.
        out.push(new TextRun({ ...baseProps, text: `[image: ${t.text || t.href}]` }));
        break;

      case "escape":
        out.push(new TextRun({ ...baseProps, text: t.text }));
        break;

      default:
        // Unknown inline — surface the raw text so we don't lose it.
        if (t.text) out.push(new TextRun({ ...baseProps, text: t.text }));
    }
  }
  return out;
}

// Decode the handful of HTML entities marked passes through verbatim
// (it expands most, but `&amp;` etc. in code spans survive).
function decodeEntities(s) {
  return String(s)
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

// ----- Block helpers -----------------------------------------------

function paragraphFromInline(tokens, opts = {}) {
  return new Paragraph({
    children: inlineRuns(tokens),
    spacing: { after: 120 },
    ...opts,
  });
}

function headingParagraph(depth, tokens) {
  const heading =
    depth === 1
      ? HeadingLevel.HEADING_1
      : depth === 2
        ? HeadingLevel.HEADING_2
        : depth === 3
          ? HeadingLevel.HEADING_3
          : HeadingLevel.HEADING_4;
  return new Paragraph({
    heading,
    children: inlineRuns(tokens),
  });
}

function codeBlockParagraphs(text, lang) {
  // Multi-line code blocks become one Paragraph per source line so
  // line breaks render correctly + each line gets its own grey shading
  // run (Word renders shading across the full content area for a
  // shaded paragraph — easier than spanning a single multi-line run).
  const lines = text.replace(/\n+$/, "").split("\n");
  return lines.map(
    (line, i) =>
      new Paragraph({
        children: [
          new TextRun({
            text: line.length ? line : " ",
            font: MONO_FONT,
            size: 20, // 10pt
          }),
        ],
        shading: { fill: CODE_BG, type: ShadingType.CLEAR },
        spacing: {
          before: i === 0 ? 80 : 0,
          after: i === lines.length - 1 ? 160 : 0,
        },
        indent: { left: 360 },
      })
  );
}

function blockquoteParagraphs(tokens) {
  // Recurse into the blockquote's body to handle nested paragraphs +
  // lists, then style every resulting paragraph with the warning
  // callout look (pale yellow shading, amber left border, indented).
  const body = blockTokensToElements(tokens);
  return body.map((el) => {
    if (el instanceof Paragraph) {
      // docx-js Paragraphs are constructed once — to mutate we'd need
      // to rebuild. We can't easily access internals, so we re-wrap
      // by rebuilding from the original tokens. For simplicity, accept
      // a small visual fidelity loss: blockquotes get only the
      // shading + indent applied by re-creating with new opts. Since
      // we recursed via blockTokensToElements, the original token
      // walker already yielded Paragraphs without the callout look.
      // Fall through: re-emit each token bucket as a styled paragraph.
    }
    return el;
  });
}

// Rebuild blockquote children with callout styling baked in. The
// renderer above hands tokens to us — we re-walk the inner tokens
// here so we can style each paragraph from the start (avoids the
// "Paragraph is immutable post-construction" issue).
function blockquoteToParagraphs(quoteTokens) {
  const out = [];
  for (const t of quoteTokens || []) {
    if (t.type === "paragraph") {
      out.push(
        new Paragraph({
          children: inlineRuns(t.tokens),
          shading: { fill: QUOTE_BG, type: ShadingType.CLEAR },
          border: {
            left: {
              style: BorderStyle.SINGLE,
              size: 18,
              color: QUOTE_BORDER,
              space: 8,
            },
          },
          indent: { left: 240 },
          spacing: { before: 120, after: 120 },
        })
      );
    } else if (t.type === "list") {
      // Lists inside a blockquote — style each list item like a quote
      // line.
      for (const item of t.items) {
        out.push(...listItemParagraphs(item, !!t.ordered, 0, /*quote=*/true));
      }
    } else if (t.type === "blockquote") {
      out.push(...blockquoteToParagraphs(t.tokens));
    } else if (t.type === "code") {
      out.push(...codeBlockParagraphs(t.text, t.lang));
    } else if (t.type === "space") {
      // skip
    } else {
      // fallback
      out.push(
        new Paragraph({
          children: inlineRuns(t.tokens || [{ type: "text", text: t.raw || "" }]),
          shading: { fill: QUOTE_BG, type: ShadingType.CLEAR },
          indent: { left: 240 },
        })
      );
    }
  }
  return out;
}

function listItemParagraphs(item, ordered, level, quote = false) {
  // A list item can itself contain paragraphs, code blocks, sub-lists.
  // First child is the item's leading line of text (use the list
  // reference for bullets/numbering); follow-ups (sub-paragraphs, code,
  // nested lists) sit underneath without re-bulleting.
  const out = [];
  const reference = ordered ? "numbers" : "bullets";

  let leadDone = false;
  for (const child of item.tokens || []) {
    if (child.type === "text") {
      // marked emits a `text` token wrapping the inline content of the
      // item's first line. Subsequent text tokens are "loose" — treat
      // them as plain paragraphs under the item.
      const runs = inlineRuns(child.tokens || [{ type: "text", text: child.text }]);
      if (!leadDone) {
        out.push(
          new Paragraph({
            children: runs,
            numbering: { reference, level },
            spacing: { after: 80 },
            ...(quote && {
              shading: { fill: QUOTE_BG, type: ShadingType.CLEAR },
              border: {
                left: {
                  style: BorderStyle.SINGLE,
                  size: 18,
                  color: QUOTE_BORDER,
                  space: 8,
                },
              },
            }),
          })
        );
        leadDone = true;
      } else {
        out.push(
          new Paragraph({
            children: runs,
            indent: { left: 720 * (level + 1) },
            spacing: { after: 80 },
          })
        );
      }
    } else if (child.type === "paragraph") {
      const runs = inlineRuns(child.tokens);
      if (!leadDone) {
        out.push(
          new Paragraph({
            children: runs,
            numbering: { reference, level },
            spacing: { after: 80 },
          })
        );
        leadDone = true;
      } else {
        out.push(
          new Paragraph({
            children: runs,
            indent: { left: 720 * (level + 1) },
            spacing: { after: 80 },
          })
        );
      }
    } else if (child.type === "list") {
      for (const sub of child.items) {
        out.push(...listItemParagraphs(sub, !!child.ordered, level + 1, quote));
      }
    } else if (child.type === "code") {
      out.push(...codeBlockParagraphs(child.text, child.lang));
    } else if (child.type === "blockquote") {
      out.push(...blockquoteToParagraphs(child.tokens));
    } else if (child.type === "space") {
      // skip
    }
  }
  return out;
}

function tableElement(token) {
  // Column widths split the content area evenly. INSTALL.md tables are
  // small (2-3 columns); equal split renders fine for these.
  const numCols = token.header.length;
  const colWidth = Math.floor(CONTENT_WIDTH_DXA / numCols);
  const widths = Array.from({ length: numCols }, () => colWidth);
  const border = { style: BorderStyle.SINGLE, size: 4, color: TABLE_BORDER };
  const borders = { top: border, bottom: border, left: border, right: border };

  const headerRow = new TableRow({
    tableHeader: true,
    children: token.header.map(
      (cell, idx) =>
        new TableCell({
          width: { size: widths[idx], type: WidthType.DXA },
          shading: { fill: TABLE_HEADER_BG, type: ShadingType.CLEAR },
          borders,
          margins: { top: 80, bottom: 80, left: 120, right: 120 },
          verticalAlign: VerticalAlign.CENTER,
          children: [
            new Paragraph({
              children: inlineRuns(cell.tokens, { bold: true }),
            }),
          ],
        })
    ),
  });

  const bodyRows = token.rows.map(
    (row) =>
      new TableRow({
        children: row.map(
          (cell, idx) =>
            new TableCell({
              width: { size: widths[idx], type: WidthType.DXA },
              borders,
              margins: { top: 80, bottom: 80, left: 120, right: 120 },
              verticalAlign: VerticalAlign.TOP,
              children: [
                new Paragraph({
                  children: inlineRuns(cell.tokens),
                }),
              ],
            })
        ),
      })
  );

  return new Table({
    width: { size: CONTENT_WIDTH_DXA, type: WidthType.DXA },
    columnWidths: widths,
    rows: [headerRow, ...bodyRows],
  });
}

// Horizontal rule — a paragraph with just a bottom border. (See docx
// skill notes: tables as rules render as empty boxes with min height.)
function horizontalRule() {
  return new Paragraph({
    border: {
      bottom: {
        style: BorderStyle.SINGLE,
        size: 6,
        color: SUBTLE_GREY,
        space: 1,
      },
    },
    spacing: { before: 200, after: 200 },
    children: [new TextRun(" ")],
  });
}

// ----- Top-level block walker --------------------------------------

function blockTokensToElements(tokens) {
  const out = [];
  for (const t of tokens || []) {
    switch (t.type) {
      case "heading":
        out.push(headingParagraph(t.depth, t.tokens));
        break;
      case "paragraph":
        out.push(paragraphFromInline(t.tokens));
        break;
      case "code":
        out.push(...codeBlockParagraphs(t.text, t.lang));
        break;
      case "blockquote":
        out.push(...blockquoteToParagraphs(t.tokens));
        break;
      case "list":
        for (const item of t.items) {
          out.push(...listItemParagraphs(item, !!t.ordered, 0));
        }
        break;
      case "table":
        out.push(tableElement(t));
        // small spacer paragraph so the next block doesn't hug the table
        out.push(new Paragraph({ children: [new TextRun(" ")], spacing: { after: 60 } }));
        break;
      case "hr":
        out.push(horizontalRule());
        break;
      case "space":
        // marked emits these between blocks; the per-paragraph
        // `spacing.after` already gives us breathing room.
        break;
      case "html":
        // Bare HTML in the source — surface its text if any so we
        // don't silently drop content.
        out.push(
          new Paragraph({
            children: [new TextRun({ text: t.text.replace(/<[^>]+>/g, ""), italics: true })],
          })
        );
        break;
      default:
        if (t.tokens) {
          out.push(...blockTokensToElements(t.tokens));
        } else if (t.text) {
          out.push(new Paragraph({ children: [new TextRun(t.text)] }));
        }
    }
  }
  return out;
}

// ----- Build the document ------------------------------------------

console.log(`→ Parsing  markdown (${md.split("\n").length} lines)`);
const tokens = marked.lexer(md);

console.log(`→ Building docx model`);

// Cover-page elements: title (from first H1) + regen date + page break.
// The first H1 in INSTALL.md is "Kiosk install & operations guide" —
// re-use it so the cover and the body's first heading don't repeat
// (drop the in-body H1 below).
let firstHeadingText = "Victron Exhibition Kiosk Apps — User Manual";
const firstHeading = tokens.find((t) => t.type === "heading" && t.depth === 1);
if (firstHeading) {
  firstHeadingText = firstHeading.text;
}

const coverChildren = [
  new Paragraph({ children: [new TextRun(" ")], spacing: { after: 1200 } }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    children: [
      new TextRun({
        text: "Victron Exhibition",
        bold: true,
        size: 52,
        font: HEADING_FONT,
        color: VICTRON_BLUE,
      }),
    ],
    spacing: { after: 120 },
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    children: [
      new TextRun({
        text: "Kiosk Apps — User Manual",
        bold: true,
        size: 44,
        font: HEADING_FONT,
        color: VICTRON_BLUE,
      }),
    ],
    spacing: { after: 480 },
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    children: [
      new TextRun({
        text: firstHeadingText,
        italics: true,
        size: 26,
        color: TEXT_GREY,
      }),
    ],
    spacing: { after: 1600 },
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    children: [
      new TextRun({
        text: `Last regenerated: ${stamp}`,
        size: 22,
        color: SUBTLE_GREY,
      }),
    ],
    spacing: { after: 120 },
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    children: [
      new TextRun({
        text: "Generated from kiosk/INSTALL.md in the victron-exhibition-apps repo.",
        size: 18,
        color: SUBTLE_GREY,
      }),
    ],
  }),
  new Paragraph({ children: [new PageBreak()] }),
];

// Table of Contents page — populated by Word/Google Docs when the
// reader opens the file (right-click → Update Field).
const tocChildren = [
  new Paragraph({
    children: [
      new TextRun({
        text: "Contents",
        bold: true,
        size: 36,
        font: HEADING_FONT,
        color: VICTRON_BLUE,
      }),
    ],
    spacing: { after: 240 },
  }),
  new TableOfContents("Contents", {
    hyperlink: true,
    headingStyleRange: "1-3",
  }),
  new Paragraph({ children: [new PageBreak()] }),
];

// Body — skip the source's first H1 (we used it on the cover).
const bodyTokens = firstHeading
  ? tokens.filter((t, i) => !(t === firstHeading))
  : tokens;
const bodyChildren = blockTokensToElements(bodyTokens);

// ----- Document assembly -------------------------------------------

const doc = new Document({
  creator: "victron-exhibition-apps build-docx.sh",
  description: "User manual regenerated from kiosk/INSTALL.md",
  title: "Victron Exhibition Kiosk Apps — User Manual",
  styles: {
    default: {
      document: { run: { font: BODY_FONT, size: 22, color: TEXT_GREY } }, // 11pt
    },
    paragraphStyles: [
      {
        id: "Heading1",
        name: "Heading 1",
        basedOn: "Normal",
        next: "Normal",
        quickFormat: true,
        run: { size: 36, bold: true, font: HEADING_FONT, color: VICTRON_BLUE },
        paragraph: { spacing: { before: 360, after: 200 }, outlineLevel: 0 },
      },
      {
        id: "Heading2",
        name: "Heading 2",
        basedOn: "Normal",
        next: "Normal",
        quickFormat: true,
        run: { size: 30, bold: true, font: HEADING_FONT, color: VICTRON_BLUE },
        paragraph: { spacing: { before: 280, after: 160 }, outlineLevel: 1 },
      },
      {
        id: "Heading3",
        name: "Heading 3",
        basedOn: "Normal",
        next: "Normal",
        quickFormat: true,
        run: { size: 26, bold: true, font: HEADING_FONT, color: TEXT_GREY },
        paragraph: { spacing: { before: 200, after: 120 }, outlineLevel: 2 },
      },
      {
        id: "Heading4",
        name: "Heading 4",
        basedOn: "Normal",
        next: "Normal",
        quickFormat: true,
        run: { size: 24, bold: true, font: HEADING_FONT, color: TEXT_GREY },
        paragraph: { spacing: { before: 160, after: 100 }, outlineLevel: 3 },
      },
    ],
  },
  numbering: { config: listNumberingConfig() },
  sections: [
    {
      properties: {
        page: {
          size: { width: PAGE_WIDTH_DXA, height: 15840 },
          margin: {
            top: MARGIN_DXA,
            right: MARGIN_DXA,
            bottom: MARGIN_DXA,
            left: MARGIN_DXA,
          },
        },
      },
      footers: {
        default: new Footer({
          children: [
            new Paragraph({
              tabStops: [
                { type: TabStopType.RIGHT, position: CONTENT_WIDTH_DXA },
              ],
              children: [
                new TextRun({
                  text: "Victron Exhibition Kiosk Apps",
                  size: 18,
                  color: SUBTLE_GREY,
                }),
                new TextRun({
                  children: [new Tab(), "Page ", PageNumber.CURRENT, " / ", PageNumber.TOTAL_PAGES],
                  size: 18,
                  color: SUBTLE_GREY,
                }),
              ],
            }),
          ],
        }),
      },
      children: [...coverChildren, ...tocChildren, ...bodyChildren],
    },
  ],
});

// ----- Write out ---------------------------------------------------

Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync(OUTPUT, buffer);
  const kb = (buffer.length / 1024).toFixed(1);
  console.log(`✓ Wrote ${OUTPUT} (${kb} KB)`);
  console.log(`  → Upload to Google Drive: drag-and-drop into the existing`);
  console.log(`    "Victron Exhibition Kiosk Apps — User Manual" doc, or`);
  console.log(`    create a new Doc by opening this file in Google Drive.`);
});
