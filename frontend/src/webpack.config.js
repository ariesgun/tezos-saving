module.exports = function override(config, env) {
    config.resolve.fallback = {
        "crypto": require.resolve('crypto-browserify'),
        "stream": false,
        "path": false,
    };

    return config;
}