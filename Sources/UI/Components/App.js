import React from 'react';
import ReactDOM from 'react-dom';
import { BrowserRouter as Router, Switch, Route } from 'react-router-dom';
import 'bootstrap';
import 'intl-relative-time-format';
import 'intl-relative-time-format/locale-data/en';
import 'intl-relative-time-format/locale-data/ja';
import '../Styles/Custom.scss';

import Badge from 'react-bootstrap/Badge';
import Container from 'react-bootstrap/Container';
import Dropdown from 'react-bootstrap/Dropdown';
import Form from 'react-bootstrap/Form';
import { LinkContainer } from 'react-router-bootstrap';
import Modal from 'react-bootstrap/Modal';
import Nav from 'react-bootstrap/Nav';
import Navbar from 'react-bootstrap/Navbar';
import NavDropdown from 'react-bootstrap/NavDropdown';
import Spinner from 'react-bootstrap/Spinner';

import Home from './Home';

import LoginModal from './LoginModal';
import RegisterModal from './RegisterModal';

import TranscriptionProjects from './Transcription/Projects';
import TranscriptionProject from './Transcription/Project';

import FlashcardDeck from './Flashcard/Deck';
import FlashcardDecks from './Flashcard/Decks';
import FlashcardNoteTypes from './Flashcard/NoteTypes';
import FlashcardNoteType from './Flashcard/NoteType';
import FlashcardCreateNoteModal from './Flashcard/Modals/CreateNoteModal';

import MediaYouTubePlayer from './Media/YouTubePlayer';

import TestsPitchAccentMinimalPairs from './Tests/PitchAccent/MinimalPairs'

import AdminUsers from './Admin/Users'

import ResetPassword from './ResetPassword'

import UserContext from './Context/User';

class App extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showRegisterModal: false,
            showLoginModal: false,
            showCreateNoteModal: false,
            user: null,
            isReady: false,

            numberOfReviews: 0,

            query: '',
            results: [],
            isLoading: true,
            isFocused: false,
            selectedResult: null,
            selectedResultHTML: ''
        };
    }

    componentDidMount() {
        this.loadUser();
        this.update();
        setInterval(() => {
            if (this.state.user) {
                this.update();
            }
        }, 30000);

        function insertTextAtCursor(text) {
            let sel, range, html;
            if (window.getSelection) {
                sel = window.getSelection();
                if (sel.getRangeAt && sel.rangeCount) {
                    range = sel.getRangeAt(0);
                    range.deleteContents();
                    range.insertNode(document.createTextNode(text));
                }
            } else if (document.selection && document.selection.createRange) {
                document.selection.createRange().text = text;
            }
        }

        function addLiveEventListeners(selector, event, handler){
            document.querySelector("body").addEventListener(event, (evt) => {
                let target = evt.target;
                while (target) {
                    var isMatch = target.matches(selector);
                    if (isMatch) {
                        handler(evt);
                       return;
                   }
                   target = target.parentElement;
               }
           }, true);
       }

       addLiveEventListeners('.plaintext[contenteditable]', 'paste', (e) => {
            e.preventDefault();
            if (e.clipboardData && e.clipboardData.getData) {
                const text = e.clipboardData.getData("text/plain");
                document.execCommand("insertHTML", false, text);
            } else if (window.clipboardData && window.clipboardData.getData) {
                const text = window.clipboardData.getData("Text");
                insertTextAtCursor(text);
            }
        });

        addLiveEventListeners('div.plaintext[contenteditable]', 'keypress', (e) => {
            if (e.keyCode == 13) {
                e.preventDefault();
            }
        });
    }

    async loadUser() {
        const response = await fetch('/api/me');
        const user = await response.json();
        if (!user.error) {
            this.setState({ user });
        }
        this.setState({ isReady: true });
    }

    async update() {
        const response = await fetch('/api/flashcard/numberOfReviews');
        const numberOfReviews = response.ok ? (parseInt(await response.text()) || 0) : 0;
        this.setState({ numberOfReviews });
    }

    toggleRegisterModal(show) {
        this.setState({ showRegisterModal: show });
    }

    toggleLoginModal(show) {
        this.setState({ showLoginModal: show });
    }

    toggleCreateNoteModal(show) {
        this.setState({ showCreateNoteModal: show });
    }

    async logout() {
        const response = await fetch('/api/auth/logout');
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

    loginProtect(view) {
        if (this.state.user) {
            return view;
        }

        return <LoginModal show backdrop="static" onHide={() => this.loadUser()} />;
    }

    render() {
        return (
            <UserContext.Provider value={this.state.user}>
                <Router>
                    <Navbar bg="dark" variant="dark" className="justify-content-sm-between justify-content-center px-xl-5 px-2">
                        <LinkContainer to="/" className='d-block d-sm-none'>
                            <Navbar.Brand>コツ</Navbar.Brand>
                        </LinkContainer>
                        <div className="col-12 d-block d-sm-none"></div>
                        <div className="d-flex navbar-expand align-items-center  order-0">
                            <LinkContainer to="/" className='d-none d-sm-block'>
                                <Navbar.Brand>コツ</Navbar.Brand>
                            </LinkContainer>
                            {this.state.user && <Nav className="mr-auto" activeKey={window.location.pathname}>
                                <LinkContainer exact to="/transcription">
                                    <Nav.Link active={false}>Transcription</Nav.Link>
                                </LinkContainer>

                                <NavDropdown title={<>Anki{this.state.numberOfReviews > 0 && <Badge className="ms-2 bg-secondary">{this.state.numberOfReviews}</Badge>}</>}>
                                    <LinkContainer to="/flashcard/decks">
                                        <NavDropdown.Item active={false}>Decks</NavDropdown.Item>
                                    </LinkContainer>
                                    <LinkContainer to="/flashcard/types">
                                        <NavDropdown.Item active={false}>Note Types</NavDropdown.Item>
                                    </LinkContainer>
                                    <LinkContainer to="/flashcard/cards">
                                        <NavDropdown.Item active={false}>Browse Cards</NavDropdown.Item>
                                    </LinkContainer>
                                    <NavDropdown.Divider />
                                    <NavDropdown.Item onClick={() => this.toggleCreateNoteModal(true)}>Create Note</NavDropdown.Item>
                                </NavDropdown>

                                <NavDropdown title='Media'>
                                    <LinkContainer to="/media/youtube">
                                        <NavDropdown.Item active={false}>YouTube</NavDropdown.Item>
                                    </LinkContainer>
                                </NavDropdown>

                                <NavDropdown title='Tests'>
                                    <LinkContainer to="/tests/pitchAccent/minimalPairs">
                                        <NavDropdown.Item active={false}>Pitch Accent (Minimal Pairs)</NavDropdown.Item>
                                    </LinkContainer>
                                </NavDropdown>

                                {this.state.user.permissions.includes('admin') && <>
                                    <NavDropdown title='Admin'>
                                        <LinkContainer to="/admin/users">
                                            <NavDropdown.Item active={false}>Users</NavDropdown.Item>
                                        </LinkContainer>
                                    </NavDropdown>
                                </>}
                            </Nav>}
                        </div>
                        {this.state.user && <Form as="div" className="mr-auto col-12 mt-1 mt-xl-0 col-xl-6 d-inline order-3 order-xl-1">
                            <Dropdown>
                                <Form.Control type="text" placeholder="Search" className="mr-sm-2 text-center" onChange={(e) => this.search(e.target.value)} onFocus={() => this.setState({ isFocused: true })} />
                                <Dropdown.Menu show className="dropdown-menu-center" style={{ 'display': (!this.state.selectedResult && this.state.query.length > 0 && this.state.isFocused) ? 'block' : 'none'}}>
                                    {this.state.results.map((r, i) => {
                                        return <Dropdown.Item as="button" onClick={() => this.loadResult(r)} style={{ 'white-space': 'normal' }} eventKey={i} key={i}>{r.headline}</Dropdown.Item>;
                                    })}
                                </Dropdown.Menu>
                            </Dropdown>
                        </Form>}
                        <div className="col-12 d-block d-xl-none order-2 order-xl-4"></div>
                        {!this.state.user && <Nav className="order-2 order-xl-4">
                            <Nav.Link href="#" onClick={() => this.toggleLoginModal(true)}>Login</Nav.Link>
                            <Nav.Link href="#" onClick={() => this.toggleRegisterModal(true)}>Register</Nav.Link>
                        </Nav>}

                        {this.state.user && <Nav className="order-1 order-xl-3">
                            <Navbar.Text className="d-sm-block d-none">
                                Logged in as: <strong>{this.state.user.username}</strong>
                            </Navbar.Text>
                            <Nav.Link href="#" onClick={() => this.logout()}>Logout</Nav.Link>
                        </Nav>}
                    </Navbar>

                    <Container className='pt-3'>
                        {!this.state.isReady && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}
                        {this.state.isReady && <Switch>
                            <Route exact path="/">
                                <Home />
                            </Route>

                            <Route exact path="/transcription">
                                {this.loginProtect(<TranscriptionProjects />)}
                            </Route>

                            <Route path="/transcription/:id">
                                <TranscriptionProject />
                            </Route>

                            <Route path="/flashcard/decks">
                                {this.loginProtect(<FlashcardDecks />)}
                            </Route>

                            <Route path="/flashcard/deck/:id">
                                {this.loginProtect(<FlashcardDeck />)}
                            </Route>

                            <Route path="/flashcard/types">
                                {this.loginProtect(<FlashcardNoteTypes />)}
                            </Route>

                            <Route path="/flashcard/type/:id">
                                {this.loginProtect(<FlashcardNoteType />)}
                            </Route>

                            <Route path="/media/youtube">
                                {this.loginProtect(<MediaYouTubePlayer />)}
                            </Route>

                            <Route path="/admin/users">
                                {this.loginProtect(<AdminUsers />)}
                            </Route>

                            <Route path="/auth/resetPassword/:userID/:key">
                                <ResetPassword show backdrop='static' />
                            </Route>

                            <Route path="/tests/pitchAccent/minimalPairs">
                                {this.loginProtect(<TestsPitchAccentMinimalPairs />)}
                            </Route>
                        </Switch>}
                    </Container>

                    <LoginModal show={this.state.showLoginModal} onHide={() => this.toggleLoginModal(false)} />
                    <RegisterModal show={this.state.showRegisterModal} onHide={() => this.toggleRegisterModal(false)} />
                    <FlashcardCreateNoteModal show={this.state.showCreateNoteModal} onHide={() => this.toggleCreateNoteModal(false)} onSuccess={() => this.toggleCreateNoteModal(false)} />

                    {this.state.selectedResult && <Modal size="lg" show={!!this.state.selectedResult} onHide={() => this.setState({ selectedResult: null, selectedResultHTML: '', isFocused: false })} centered>
                        <Modal.Header closeButton>
                            <Modal.Title>{this.state.selectedResult.headline}</Modal.Title>
                        </Modal.Header>
                        <Modal.Body>
                            {this.state.isLoading && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}
                            {!this.state.isLoading && <iframe className="col-12" style={{ height: '60vh' }} srcDoc={this.state.selectedResultHTML} frameBorder="0"></iframe>}
                        </Modal.Body>
                    </Modal>}
                </Router>
            </UserContext.Provider>
        );
    }
}

ReactDOM.render(<App />, document.getElementById('app'));
