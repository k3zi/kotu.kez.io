const MiniCssExtractPlugin = require("mini-css-extract-plugin");

module.exports = {
    entry: "./Sources/UI/Components/Main.js",
    module: {
        rules: [
            {
                test: /\.(js|jsx)$/,
                exclude: /node_modules/,
                use: ["babel-loader"]
            },
            {
                test: /\.s[ac]ss$/i,
                use: [
                    MiniCssExtractPlugin.loader,
                    "css-loader",
                    "sass-loader",
                ],
            }
      ]
    },
    resolve: {
        extensions: ["*", ".js", ".jsx"]
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
            filename: "[name].css",
            chunkFilename: "[id].css"
        })
    ]
};
