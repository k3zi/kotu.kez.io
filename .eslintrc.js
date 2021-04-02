module.exports = {
  env: {
    browser: true,
    es2021: true
  },
  extends: ["eslint:recommended", "plugin:react/recommended"],
  parserOptions: {
    ecmaFeatures: {
      jsx: true
    },
    ecmaVersion: 12,
    sourceType: "module"
  },
  plugins: ["react"],
  rules: {
    indent: ["error", 4],
    "linebreak-style": ["error", "unix"],
    quotes: ["error", "single"],
    semi: ["error", "always"],
    "react/jsx-first-prop-new-line": "never"
  },
  settings: {
    react: {
      version: "detect"
    }
  }
};
