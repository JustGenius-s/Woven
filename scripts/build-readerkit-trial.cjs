const { main } = require('./build-readerkit-book.cjs');
if (require.main === module) main().catch(error => { console.error(error.stack); process.exitCode = 1; });
