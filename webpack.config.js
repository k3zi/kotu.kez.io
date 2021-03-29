const MiniCssExtractPlugin = require("mini-css-extract-plugin");

module.exports = {
    entry: "./Sources/UI/Components/App.js",
    module: {
        rules: [
            {
                test: /\.(js|jsx)$/,
                exclude: /node_modules/,
                use: ["babel-loader"]
            },
            {
                test: /\.(css|sass|scss)$/,
                use: [
                    MiniCssExtractPlugin.loader,
                    "css-loader",
                    'postcss-loader',
                    "sass-loader",
                ],
            },
            {
                test: /\.(png|jpg|woff|woff2|eot|ttf|svg)(\?v=[0-9]\.[0-9]\.[0-9])?$/,
                use: [
                    "url-loader",
                ]
            },
            {
                test: /react-spring/,
                sideEffects: true
            }
        ]
    },
    resolve: {
        extensions: ["*", ".js", ".jsx"],
        fallback: {
            "string_decoder": require.resolve("string_decoder/"),
            "stream": require.resolve("stream-browserify"),
            "buffer": require.resolve("buffer/")
        }
    },
    output: {
        path: __dirname + "/Public/generated",
        publicPath: "/",
        filename: "bundle.js"
    },
    devServer: {
        contentBase: "./Public/generated"
    },
    plugins: [
        new MiniCssExtractPlugin({
            filename: "bundle.css",
            chunkFilename: "[id].css"
        })
    ]
};
