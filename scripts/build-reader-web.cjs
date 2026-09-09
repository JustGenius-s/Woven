// Build the complete semantic book used by the current application.
if (process.argv.includes('--trial')) {
  console.error('The legacy overlay is archived. For the standalone approved preview, use scripts/rebuild-reader-semantic-trial.cjs with --pdf and --python.');
  process.exitCode = 1;
} else {
  require('./rebuild-reader-semantic-full.cjs').main().catch(error => {
    console.error(error.stack);
    process.exitCode = 1;
  });
}
