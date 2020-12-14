import React from "react";
import ReactDOM from "react-dom";
import { BrowserRouter as Router, Route, Link } from "react-router-dom";
import "bootstrap";
import "../Styles/Custom.scss";

import Component from "./Home"
import ViewSubtitles from "./YouTube"

class App extends React.Component {
    render() {
        return (
            <Router>
                <div>
                    <Route exact path="/" component={Component} />
                    <Route path="/subtitles" component={ViewSubtitles} />

                    <Link to="/">Home</Link>
                    <Link to="/subtitles">Subtitles</Link>
                </div>
            </Router>
        )
    }
}

ReactDOM.render(<App />, document.getElementById("app"))
