import React from "react";
import ReactDOM from "react-dom";
import { BrowserRouter as Router, Switch, Route } from "react-router-dom";
import "bootstrap";
import "../Styles/Custom.scss";

import Container from 'react-bootstrap/Container';
import Dropdown from 'react-bootstrap/Dropdown';
import Form from 'react-bootstrap/Form';
import { LinkContainer } from 'react-router-bootstrap';
import Modal from 'react-bootstrap/Modal';
import Nav from 'react-bootstrap/Nav';
import Navbar from 'react-bootstrap/Navbar';
import Spinner from 'react-bootstrap/Spinner';

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
            user: null,

            query: "",
            results: [],
            isLoading: true,
            selectedResult: null,
            selectedResultHTML: ""
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

    async search(query) {
        this.setState({ query, results: [], isLoading: true });
        if (query.length === 0) return;
        const response = await fetch(`/api/dictionary/search?q=${encodeURIComponent(query)}`);
        const results = await response.json();
        this.setState({ results, isLoading: false });
    }

    async loadResult(headword) {
        this.setState({ selectedResult: headword, isLoading: true });
        const response = await fetch(`/api/dictionary/entry/${headword.id}`);
        const result = await response.text();
        this.setState({ selectedResultHTML: result, isLoading: false });
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
                        <Form as="div" className="mr-auto w-50 d-inline">
                            <Dropdown>
                                <Form.Control type="text" placeholder="Search" className="mr-sm-2 text-center" onChange={(e) => this.search(e.target.value)} />
                                <Dropdown.Menu show className="dropdown-menu-center" style={{ "display": (!this.state.selectedResult && this.state.query.length > 0) ? "block" : "none"}}>
                                    {this.state.results.map((r, i) => {
                                        return <Dropdown.Item as="button" onClick={() => this.loadResult(r)} style={{ "white-space": "normal" }} eventKey={i} key={i}>{r.headline}</Dropdown.Item>;
                                    })}
                                </Dropdown.Menu>
                            </Dropdown>
                        </Form>
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

                    {this.state.selectedResult && <Modal size="lg" show={!!this.state.selectedResult} onHide={() => this.setState({ selectedResult: null, selectedResultHTML: "" })} centered>
                        <Modal.Header closeButton>
                            <Modal.Title>{this.state.selectedResult.headline}</Modal.Title>
                        </Modal.Header>
                        <Modal.Body>
                            {this.state.isLoading && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}
                            {!this.state.isLoading && <iframe className="w-100" height="400px" srcDoc={this.state.selectedResultHTML} scrolling="no" frameBorder="0"></iframe>}
                        </Modal.Body>
                    </Modal>}
                </Router>
            </UserContext.Provider>
        )
    }
}

ReactDOM.render(<App />, document.getElementById("app"));
