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
import LoginModal from "./LoginModal";
import RegisterModal from "./RegisterModal";
import TranscriptionProjects from "./Transcription/Projects";
import TranscriptionProject from "./Transcription/Project";

const UserContext = React.createContext(null);

class App extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showRegisterModal: false,
            showLoginModal: false,
            user: null
        };
    }

    async componentDidMount() {
        const response = await fetch(`/api/me`);
        const user = await response.json();
        if (!user.error) {
            this.setState({ user });
        }
    }

    toggleRegisterModal(show) {
        this.setState({ showRegisterModal: show });
    }

    toggleLoginModal(show) {
        this.setState({ showLoginModal: show });
    }

    async logout() {
        const response = await fetch(`/api/auth/logout`);
        if (response.ok) {
            location.reload();
        }
    }

    render() {
        return (
            <UserContext.Provider value={this.state.user}>
                <Router>
                    <Navbar bg="dark" variant="dark">
                        <LinkContainer to="/">
                            <Navbar.Brand>コツ</Navbar.Brand>
                        </LinkContainer>
                        <Nav className="mr-auto" activeKey={window.location.pathname}>
                            <LinkContainer to="/transcription">
                                <Nav.Link eventKey="/transcription">Transcription</Nav.Link>
                            </LinkContainer>
                        </Nav>
                        {!this.state.user && <Nav>
                            <Nav.Link href="#" onClick={() => this.toggleLoginModal(true)}>Login</Nav.Link>
                            <Nav.Link href="#" onClick={() => this.toggleRegisterModal(true)}>Register</Nav.Link>
                        </Nav>}

                        {this.state.user && <Nav>
                            <Navbar.Text>
                                Logged in as: <strong>{this.state.user.username}</strong>
                            </Navbar.Text>
                            <Nav.Link href="#" onClick={() => this.logout()}>Logout</Nav.Link>
                        </Nav>}
                    </Navbar>

                    <Container>
                        <Switch>
                            <Route exact path="/">
                                <Home />
                            </Route>

                            <Route exact path="/transcription">
                                <TranscriptionProjects />
                            </Route>

                            <Route path="/transcription/:id">
                                <TranscriptionProject />
                            </Route>
                        </Switch>
                    </Container>

                    <LoginModal show={this.state.showLoginModal} onHide={() => this.toggleLoginModal(false)} />
                    <RegisterModal show={this.state.showRegisterModal} onHide={() => this.toggleRegisterModal(false)} />
                </Router>
            </UserContext.Provider>
        )
    }
}

ReactDOM.render(<App />, document.getElementById("app"));
