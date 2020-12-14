import React from "react";
import ReactDOM from "react-dom";
import { BrowserRouter as Router, Route, Link } from "react-router-dom";
import "bootstrap";
import "../Styles/Custom.scss";

import Home from "./Home";
import ViewSubtitles from "./YouTube";

import RegisterModal from "./RegisterModal";

import Nav from 'react-bootstrap/Nav';
import Navbar from 'react-bootstrap/Navbar';

class App extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showRegisterModal: false
        };
    }

    hideRegisterModal() {
        this.setState({ showRegisterModal: false });
    }

    showRegisterModal() {
        this.setState({ showRegisterModal: true });
    }

    render() {
        return (
            <Router>
                <Navbar bg="dark" variant="dark">
                    <Navbar.Brand href="#home">コツ</Navbar.Brand>
                    <Nav className="mr-auto">
                        <Nav.Link href="/">Home</Nav.Link>
                        <Nav.Link href="#features">Login</Nav.Link>
                        <Nav.Link href="#" onClick={() => this.showRegisterModal()}>Register</Nav.Link>
                    </Nav>
                </Navbar>
                
                <div>
                    <Route exact path="/" component={Home} />
                    <Route path="/subtitles" component={ViewSubtitles} />

                    <Link to="/">Home</Link>
                    <Link to="/subtitles">Subtitles</Link>
                </div>

                <RegisterModal show={this.state.showRegisterModal} onHide={() => this.hideRegisterModal()} />
            </Router>
        )
    }
}

ReactDOM.render(<App />, document.getElementById("app"))
