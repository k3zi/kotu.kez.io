import React from 'react';
import ReactDOM from 'react-dom';
import { BrowserRouter as Router, Switch, Route } from 'react-router-dom';
import 'bootstrap';
import 'intl-relative-time-format';
import 'intl-relative-time-format/locale-data/en';
import 'intl-relative-time-format/locale-data/ja';
import '../Styles/Custom.scss';

import Helpers from './Helpers';

import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Container from 'react-bootstrap/Container';
import Dropdown from 'react-bootstrap/Dropdown';
import Form from 'react-bootstrap/Form';
import { LinkContainer } from 'react-router-bootstrap';
import Modal from 'react-bootstrap/Modal';
import Nav from 'react-bootstrap/Nav';
import Navbar from 'react-bootstrap/Navbar';
import NavDropdown from 'react-bootstrap/NavDropdown';
import Spinner from 'react-bootstrap/Spinner';

import Changelog from './Changelog';
import Help from './Help';
import Home from './Home';

import FeedbackModal from './FeedbackModal';
import LoginModal from './LoginModal';
import RegisterModal from './RegisterModal';
import SearchResultModal from './SearchResultModal';
import SettingsModal from './SettingsModal';

import TranscriptionProjects from './Transcription/Projects';
import TranscriptionProject from './Transcription/Project';

import FlashcardDeck from './Flashcard/Deck';
import FlashcardDecks from './Flashcard/Decks';
import FlashcardNotes from './Flashcard/Notes';
import FlashcardNoteTypes from './Flashcard/NoteTypes';
import FlashcardNoteType from './Flashcard/NoteType';
import FlashcardCreateNoteModal from './Flashcard/Modals/CreateNoteModal';

import ListsWords from './Lists/Words';
import AddSentenceModal from './AddSentenceModal';

import MediaYouTubePlayer from './Media/YouTubePlayer';
import MediaPlexPlayer from './Media/PlexPlayer';
import MediaReader from './Media/Reader';

import TestsPitchAccentMinimalPairs from './Tests/PitchAccent/MinimalPairs';

import AdminUsers from './Admin/Users';

import ResetPassword from './ResetPassword';

import UserContext from './Context/User';

class App extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showFeedbackModal: false,
            showRegisterModal: false,
            showLoginModal: false,
            showCreateNoteModal: false,
            showAddSentenceModal: false,
            showSettingsModal: false,
            user: null,
            isReady: false,

            numberOfReviews: 0,

            query: '',
            results: [],
            headwords: []
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

        Helpers.addLiveEventListeners('.plaintext[contenteditable]', 'paste', (e) => {
            e.preventDefault();
            if (e.clipboardData && e.clipboardData.getData) {
                const text = e.clipboardData.getData("text/plain");
                document.execCommand("insertHTML", false, text);
            } else if (window.clipboardData && window.clipboardData.getData) {
                const text = window.clipboardData.getData("Text");
                insertTextAtCursor(text);
            }
        });

        Helpers.addLiveEventListeners('component', 'click', (e, target) => {
            const headwords = JSON.parse(target.dataset.headwords);
            this.setState({ headwords });
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
        await this.loadUser();
    }

    toggleFeedbackModal(show) {
        this.setState({ showFeedbackModal: show });
    }

    toggleRegisterModal(show) {
        this.setState({ showRegisterModal: show });
        this.loadUser();
    }

    toggleLoginModal(show) {
        this.setState({ showLoginModal: show });
        this.loadUser();
    }

    toggleCreateNoteModal(show) {
        this.setState({ showCreateNoteModal: show });
    }

    toggleAddSentenceModal(show) {
        this.setState({ showAddSentenceModal: show });
    }

    toggleShowSettingsModal(show) {
        this.setState({ showSettingsModal: show });
        this.loadUser();
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
        if (response.ok) {
            const results = await response.json();
            this.setState({ results, isLoading: false });
        }
    }

    loadResult(headword) {
        this.setState({ headwords: [headword] });
    }

    loginProtect(view) {
        if (this.state.user) {
            return view;
        }

        return <h1>Login / Register to access this page.</h1>;
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
                                    <Nav.Link active={false}>Transcribe</Nav.Link>
                                </LinkContainer>

                                <NavDropdown title={<>Anki{this.state.numberOfReviews > 0 && <Badge className="ms-2 bg-secondary">{this.state.numberOfReviews}</Badge>}</>}>
                                    <LinkContainer to="/flashcard/decks">
                                        <NavDropdown.Item active={false}>Decks</NavDropdown.Item>
                                    </LinkContainer>
                                    <LinkContainer to="/flashcard/types">
                                        <NavDropdown.Item active={false}>Note Types</NavDropdown.Item>
                                    </LinkContainer>
                                    <LinkContainer to="/flashcard/notes">
                                        <NavDropdown.Item active={false}>Browse Notes</NavDropdown.Item>
                                    </LinkContainer>
                                    <NavDropdown.Divider />
                                    <NavDropdown.Item onClick={() => this.toggleCreateNoteModal(true)}>Add Note</NavDropdown.Item>
                                </NavDropdown>

                                <NavDropdown title='Lists'>
                                    <LinkContainer to="/lists/words">
                                        <NavDropdown.Item active={false}>Words</NavDropdown.Item>
                                    </LinkContainer>
                                    <LinkContainer to="/lists/sentences">
                                        <NavDropdown.Item active={false}>Sentences</NavDropdown.Item>
                                    </LinkContainer>
                                    <NavDropdown.Divider />
                                    <NavDropdown.Item active={false} onClick={() => this.toggleAddSentenceModal(true)}>Add Sentence</NavDropdown.Item>
                                </NavDropdown>

                                <NavDropdown title='Media'>
                                    <LinkContainer to="/media/youtube">
                                        <NavDropdown.Item active={false}>YouTube</NavDropdown.Item>
                                    </LinkContainer>
                                    <LinkContainer to="/media/plex">
                                        <NavDropdown.Item active={false}>Plex</NavDropdown.Item>
                                    </LinkContainer>
                                    <LinkContainer to="/media/reader">
                                        <NavDropdown.Item active={false}>Reader</NavDropdown.Item>
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
                        {this.state.user && <Form as="div" className="mr-auto col-12 mt-1 mt-xl-0 col-xl-4 d-inline order-3 order-xl-1">
                            <Dropdown>
                                <Form.Control type="text" placeholder="Search" className="mr-sm-2 text-center" onChange={(e) => this.search(e.target.value)} onFocus={() => this.setState({ isFocused: true })} />
                                <Dropdown.Menu show className="dropdown-menu-center" style={{ 'display': (!this.state.selectedResult && this.state.query.length > 0 && this.state.isFocused) ? 'block' : 'none'}}>
                                    {this.state.results.map((r, i) => {
                                        return <Dropdown.Item className='d-flex align-items-center' as="button" onClick={() => this.loadResult(r)} style={{ 'white-space': 'normal' }} eventKey={i} key={i}>
                                            <img className='me-2' height='20px' src={`/api/dictionary/icon/${r.dictionary.id}`} />
                                            {r.headline}
                                        </Dropdown.Item>;
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

                            <NavDropdown className='dropdown-menu-end' title={<i class="bi bi-person-circle"></i>}>
                                <NavDropdown.Item active={false} onClick={() => this.toggleShowSettingsModal(true)}>Settings</NavDropdown.Item>
                                <NavDropdown.Divider />
                                <NavDropdown.Item active={false} onClick={() => this.logout()}>Logout</NavDropdown.Item>
                            </NavDropdown>
                        </Nav>}
                    </Navbar>

                    <Container className='p-4'>
                        {!this.state.isReady && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}
                        {this.state.isReady && <Switch>
                            <Route exact path="/">
                                <Home />
                            </Route>
                            <Route path="/help">
                                <Help />
                            </Route>
                            <Route path="/changelog">
                                <Changelog />
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
                            <Route path="/flashcard/notes">
                                {this.loginProtect(<FlashcardNotes />)}
                            </Route>

                            <Route path="/lists/words">
                                {this.loginProtect(<ListsWords />)}
                            </Route>

                            <Route path="/media/youtube">
                                {this.loginProtect(<MediaYouTubePlayer />)}
                            </Route>
                            <Route path="/media/plex">
                                {this.loginProtect(<MediaPlexPlayer />)}
                            </Route>
                            <Route path="/media/reader">
                                {this.loginProtect(<MediaReader />)}
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

                    <footer className="my-3 text-white-50 text-center text-small">
                        <p className="mb-1">
                            Made by <a className='text-white' href='https://kez.io'>ケジ</a>
                            ・
                            <LinkContainer to="/changelog">
                                <a className='text-white' href='#'>Changelog</a>
                            </LinkContainer>
                            ・
                            <LinkContainer to="/help">
                                <a className='text-white' href='#'>Help</a>
                            </LinkContainer>
                            ・
                            <a style={{cursor:'pointer'}} className='text-white' onClick={() => this.toggleFeedbackModal(true)}>Feedback</a>
                            ・
                            <a className='text-white' href='https://github.com/k3zi/kotu.kez.io' target='_blank'>Github</a>
                        </p>
                    </footer>

                    <FeedbackModal show={this.state.showFeedbackModal} onHide={() => this.toggleFeedbackModal(false)} />
                    <LoginModal show={this.state.showLoginModal} onHide={() => this.toggleLoginModal(false)} />
                    <RegisterModal show={this.state.showRegisterModal} onHide={() => this.toggleRegisterModal(false)} />
                    <FlashcardCreateNoteModal show={this.state.showCreateNoteModal} onHide={() => this.toggleCreateNoteModal(false)} onSuccess={() => this.toggleCreateNoteModal(false)} />
                    <AddSentenceModal show={this.state.showAddSentenceModal} onHide={() => this.toggleAddSentenceModal(false)} onSuccess={() => this.toggleAddSentenceModal(false)} />
                    <SearchResultModal headwords={this.state.headwords} show={this.state.headwords.length > 0} onHide={() => this.setState({ headwords: [], isFocused: false })} />
                    <SettingsModal user={this.state.user} show={this.state.showSettingsModal} onHide={() => this.toggleShowSettingsModal(false)} onSave={() => this.loadUser()} />
                </Router>
            </UserContext.Provider>
        );
    }
}

ReactDOM.render(<App />, document.getElementById('app'));
