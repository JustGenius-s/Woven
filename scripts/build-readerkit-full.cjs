const { main } = require('./build-readerkit-book.cjs');
if (require.main === module) main({ full: true }).catch(error => { console.error(error.stack); process.exitCode = 1; });
