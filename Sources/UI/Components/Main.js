import React from "react";
import ReactDOM from "react-dom";
import { BrowserRouter as Router, Switch, Route } from "react-router-dom";
import "bootstrap";
import "../Styles/Custom.scss";

import Container from 'react-bootstrap/Container';
import { LinkContainer } from 'react-router-bootstrap';
import Nav from 'react-bootstrap/Nav';
import Navbar from 'react-bootstrap/Navbar';

import Home from "./Home";
import RegisterModal from "./RegisterModal";
import Transcribe from "./Transcribe";

class App extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showRegisterModal: false,
            showLoginModal: false
        };
    }

    toggleRegisterModal(show) {
        this.setState({ showRegisterModal: show });
    }

    toggleLoginModal(show) {
        this.setState({ showLoginModal: show });
    }

    render() {
        return (
            <Router>
                <Navbar bg="dark" variant="dark">
                    <LinkContainer to="/">
                        <Navbar.Brand>コツ</Navbar.Brand>
                    </LinkContainer>
                    <Nav className="mr-auto" activeKey={window.location.pathname}>
                        <LinkContainer to="/transcribe">
                            <Nav.Link eventKey="/transcribe">Transcribe</Nav.Link>
                        </LinkContainer>
                    </Nav>
                    <Nav>
                        <Nav.Link href="#" onClick={() => this.toggleLoginModal(true)}>Login</Nav.Link>
                        <Nav.Link href="#" onClick={() => this.toggleRegisterModal(true)}>Register</Nav.Link>
                    </Nav>
                </Navbar>

                <Container>
                    <Switch>
                        <Route exact path="/">
                            <Home />
                        </Route>

                        <Route path="/transcribe">
                            <Transcribe />
                        </Route>
                    </Switch>
                </Container>

                <RegisterModal show={this.state.showRegisterModal} onHide={() => this.toggleRegisterModal(false)} />
            </Router>
        )
    }
}

ReactDOM.render(<App />, document.getElementById("app"))
