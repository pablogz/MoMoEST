const winston = require('winston');
const { combine, timestamp } = winston.format;

const _myFormat = winston.format.printf(({ level, message, timestamp }) => { return `[[${level}]] || ${timestamp} || ${message}`; });


const logger = winston.createLogger({
    format: combine(
        timestamp(),
        _myFormat
    ),
    transports: [
        new winston.transports.File(
            {
                filename: './log/events.log',
                level: 'debug',
                maxsize: 20971520,
            }),
    ],
    exitOnError: false,
    exceptionHandlers: [
        new winston.transports.File({
            filename: './log/exceptions.log'
        })
    ],
});

module.exports = logger;