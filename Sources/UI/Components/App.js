import _ from 'underscore';
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
import DropdownButton from 'react-bootstrap/DropdownButton';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import { LinkContainer } from 'react-router-bootstrap';
import Modal from 'react-bootstrap/Modal';
import Nav from 'react-bootstrap/Nav';
import Navbar from 'react-bootstrap/Navbar';
import NavDropdown from 'react-bootstrap/NavDropdown';
import Spinner from 'react-bootstrap/Spinner';

import Changelog from './Changelog';
import Help from './Help';
import Home from './Home';
import Search from './Search';

import FeedbackModal from './FeedbackModal';
import LoginModal from './LoginModal';
import RegisterModal from './RegisterModal';
import SearchResultModal from './SearchResultModal';
import SettingsModal from './SettingsModal';
import ContextMenu from './ContextMenu';

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
import TestsPitchAccentNames from './Tests/PitchAccent/Names';
import TestsPitchAccentCounters from './Tests/PitchAccent/Counters';

import AdminUsers from './Admin/Users';
import AdminFeedback from './Admin/Feedback';

import ResetPassword from './ResetPassword';

import BlogPost from './Blog/BlogPost';
import BlogPosts from './Blog/BlogPosts';
import EditBlogPost from './Blog/EditBlogPost';

import UserContext from './Context/User';
import ColorSchemeContext from './Context/ColorScheme';

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
            showContextMenu: {},

            numberOfReviews: 0,

            query: '',
            results: [],
            subtitles: [],
            headwords: [],
            hasDictionaries: true,
            searchNavSelectedOption: 'Words'
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

        this.updateColorScheme();
        if (window.matchMedia) {
            window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
                const colorScheme = ((this.state.user && this.state.user.settings.ui.prefersDarkMode) || e.matches) ? 'dark' : 'light';
                this.setState({ colorScheme });
            });
        }

        document.addEventListener('copy', function (e) {
            e.preventDefault();
            const rts = [...document.getElementsByTagName('rt')];
            rts.forEach(rt => {
                rt.style.display = 'none';
            });
            e.clipboardData.setData('text', window.getSelection().toString());
            rts.forEach(rt => {
                rt.style.removeProperty('display');
            });
        });

        Helpers.addLiveEventListeners('.plaintext[contenteditable]', 'paste', (e) => {
            e.preventDefault();
            if (e.clipboardData && e.clipboardData.getData) {
                const text = e.clipboardData.getData("text/plain");
                document.execCommand("insertText", false, text);
            } else if (window.clipboardData && window.clipboardData.getData) {
                const text = window.clipboardData.getData("Text");
                insertTextAtCursor(text);
            }
        });

        Helpers.addLiveEventListeners('.clickable[contenteditable]', 'contextmenu', (e, target) => {
            e.preventDefault();
            const contextMenu = {
                y: e.clientY,
                x: e.clientX,
                selection: window.getSelection().toString(),
                target
            };
            this.setState({ showContextMenu: contextMenu });
        });

        Helpers.addLiveEventListeners('component', 'click', (e, target) => {
            const original = target.dataset.original;
            const surface = target.dataset.surface;
            this.searchExact(`${original}|${surface}`);
        });

        Helpers.addLiveEventListeners('.spoiler', 'click', (e, target) => {
            target.classList.toggle('active');
        });
    }

    updateColorScheme(overrideUser) {
        const user = overrideUser || this.state.user;
        const darkMode = ((user && user.settings.ui.prefersDarkMode) || (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches));
        this.setState({ colorScheme: darkMode ? 'dark' : 'light' });
    }

    async loadUser() {
        const response = await fetch('/api/me');
        const user = await response.json();
        if (!user.error) {
            if (user.settings.ui.prefersColorContrast) {
                document.body.classList.add('prefers-color-contrast');
            } else {
                document.body.classList.remove('prefers-color-contrast');
            }

            if (user.settings.ui.prefersDarkMode) {
                document.body.classList.add('prefers-dark-mode');
            } else {
                document.body.classList.remove('prefers-dark-mode');
            }
            this.setState({ user });
            this.updateColorScheme(user);
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
            const results = (await response.json()).items;
            if (results.length === 0) {
                const response1 = await fetch(`/api/dictionary/all`);
                if (response1.ok) {
                    const dictionaries = await response1.json();
                    this.setState({ hasDictionaries: dictionaries.length > 0 });
                }
            }
            this.setState({ results });
        }

        const response2 = await fetch(`/api/media/youtube/subtitles/search?q=${encodeURIComponent(query)}`);
        const response3 = await fetch(`/api/media/anki/subtitles/search?q=${encodeURIComponent(query)}`);
        if (response2.ok && response3.ok) {
            const youTubeSubtitles = (await response2.json()).items;
            const ankiSubtites = (await response3.json()).items;
            const subtitles = _.sortBy([...youTubeSubtitles, ...ankiSubtites], 'id');

            this.setState({ subtitles });
        }
    }

    async searchExact(query) {
        if (query.length === 0) return;
        const response = await fetch(`/api/dictionary/exact?q=${encodeURIComponent(query)}`);
        if (response.ok) {
            const headwords = (await response.json()).items;
            this.setState({ headwords });
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

    playAudio(url) {
        if (this.audio) {
            this.audio.pause();
        }

        const audio = new Audio(url)
        audio.play();
        this.audio = audio;
    }

    render() {
        return (
            <UserContext.Provider value={this.state.user}>
                <ColorSchemeContext.Provider value={this.state.colorScheme}>
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
                                            <NavDropdown.Item active={false}>Notes</NavDropdown.Item>
                                        </LinkContainer>
                                        <NavDropdown.Divider />
                                        <NavDropdown.Item onClick={() => this.toggleCreateNoteModal(true)}>Add Note</NavDropdown.Item>
                                    </NavDropdown>

                                    <NavDropdown title='Lists'>
                                        <LinkContainer to="/lists/words">
                                            <NavDropdown.Item active={false}>Words</NavDropdown.Item>
                                        </LinkContainer>
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
                                        <NavDropdown.Header>Pitch Accent</NavDropdown.Header>
                                        <LinkContainer to="/tests/pitchAccent/minimalPairs">
                                            <NavDropdown.Item active={false}>Minimal Pairs (Perception)</NavDropdown.Item>
                                        </LinkContainer>
                                        <LinkContainer to="/tests/pitchAccent/names">
                                            <NavDropdown.Item active={false}>Names (Recall)</NavDropdown.Item>
                                        </LinkContainer>
                                        <LinkContainer to="/tests/pitchAccent/counters">
                                            <NavDropdown.Item active={false}>Counters (Recall)</NavDropdown.Item>
                                        </LinkContainer>
                                    </NavDropdown>

                                    <LinkContainer exact to="/articles">
                                        <Nav.Link active={false}>Articles</Nav.Link>
                                    </LinkContainer>

                                    {this.state.user.permissions.includes('admin') && <>
                                        <NavDropdown title='Admin'>
                                            <LinkContainer to="/admin/users">
                                                <NavDropdown.Item active={false}>Users</NavDropdown.Item>
                                            </LinkContainer>
                                            <LinkContainer to="/admin/feedback">
                                                <NavDropdown.Item active={false}>Feedback</NavDropdown.Item>
                                            </LinkContainer>
                                        </NavDropdown>
                                    </>}
                                </Nav>}
                            </div>
                            {this.state.user && <Form as="div" className="mr-auto col-12 mt-1 mt-xl-0 col-xl-4 d-inline order-3 order-xl-1">
                                <Dropdown>
                                    <InputGroup className="mr-sm-2">
                                        <div className='position-relative flex-fill'>
                                            <Form.Control className="text-center" type="text" placeholder="Search" onChange={(e) => this.search(e.target.value)} value={this.state.query} onFocus={() => this.setState({ isFocused: true })} />
                                            {this.state.query.length > 0 && <span onClick={() => this.search('')} className='position-absolute text-muted' style={{ top: '-4px', right: '4px', 'font-size': '1.75rem', cursor: 'pointer' }}><i class="bi bi-x"></i></span>}
                                        </div>
                                        <LinkContainer onClick={() => this.setState({ isFocused: false })} to={`/search/${encodeURIComponent(this.state.query)}`}>
                                            <Button variant="outline-secondary" disabled={this.state.query.length === 0}>
                                                <i class="bi bi-search"></i>
                                            </Button>
                                        </LinkContainer>
                                        <DropdownButton variant="outline-secondary" title={this.state.searchNavSelectedOption} onMouseDown={() => this.setState({ isFocused: false })} id="appSearchSelectedOption">
                                            {['Words', 'Examples'].map((option, i) => {
                                                return <Dropdown.Item key={i} active={this.state.searchNavSelectedOption == option} onSelect={() => this.setState({ searchNavSelectedOption: option, isFocused: true })}>{option}</Dropdown.Item>;
                                            })}
                                        </DropdownButton>
                                    </InputGroup>
                                    <Dropdown.Menu show className="dropdown-menu-start" style={{ 'display': (!this.state.selectedResult && this.state.query.length > 0 && this.state.isFocused) ? 'block' : 'none'}}>
                                        {this.state.searchNavSelectedOption == 'Words' && this.state.results.length == 0 && !this.state.hasDictionaries && <Dropdown.Item　disabled>
                                            No dictionaries. Add a dictionary in Settings.
                                        </Dropdown.Item>}
                                        {this.state.searchNavSelectedOption == 'Words' && this.state.results.map((r, i) => {
                                            return <Dropdown.Item className='d-flex align-items-center text-break text-wrap' as="button" onClick={() => this.loadResult(r)} style={{ 'white-space': 'normal' }} eventKey={i} key={i}>
                                                <img className='me-2' height='20px' src={`/api/dictionary/icon/${r.dictionary.id}`} />
                                                {r.headline}
                                            </Dropdown.Item>;
                                        })}

                                        {this.state.searchNavSelectedOption == 'Examples' && this.state.subtitles.map((s, i) => {
                                            if (s.youtubeVideo) {
                                                return <LinkContainer key={i} to={`/media/youtube/${s.youtubeVideo.youtubeID}/${s.startTime}`}>
                                                    <Dropdown.Item className='d-flex align-items-center text-break text-wrap' as="button" style={{ 'white-space': 'normal' }} eventKey={i} >
                                                        <img className='me-2' height='40px' src={s.youtubeVideo.thumbnailURL} />
                                                        {s.text}
                                                    </Dropdown.Item>
                                                </LinkContainer>;
                                            } else {
                                                return <Dropdown.Item key={i} onClick={() => this.playAudio(`/api/media/external/audio/${s.externalFile.id}`)} className='d-flex align-items-center text-break text-wrap' as="button" style={{ 'white-space': 'normal' }} eventKey={i} >
                                                    {s.text}
                                                </Dropdown.Item>;
                                            }
                                        })}
                                    </Dropdown.Menu>
                                </Dropdown>
                            </Form>}
                            <div className="col-12 d-block d-xl-none order-2 order-xl-4"></div>
                            {!this.state.user && <Nav className="order-2 order-xl-4">
                                <LinkContainer exact to="/articles">
                                    <Nav.Link active={false}>Articles</Nav.Link>
                                </LinkContainer>
                                <Nav.Link href="#" onClick={() => this.toggleLoginModal(true)}>Login</Nav.Link>
                                <Nav.Link href="#" onClick={() => this.toggleRegisterModal(true)}>Register</Nav.Link>
                            </Nav>}

                            {this.state.user && <Nav className="order-1 order-xl-3">
                                <NavDropdown className='dropdown-menu-end' title={<i class="bi bi-person-circle"></i>}>
                                    <NavDropdown.Item disabled active={false}>Logged in as: <strong>{this.state.user.username}</strong></NavDropdown.Item>
                                    <NavDropdown.Divider />
                                    <NavDropdown.Item active={false} onClick={() => this.toggleShowSettingsModal(true)}>Settings</NavDropdown.Item>
                                    <NavDropdown.Divider />
                                    <NavDropdown.Item active={false} onClick={() => this.logout()}>Logout</NavDropdown.Item>
                                </NavDropdown>
                            </Nav>}
                        </Navbar>

                        <Container id='app-container' className='p-4'>
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
                                <Route path="/search/:query?/:optionValue?/:page?/:per?">
                                    {this.loginProtect(<Search onSelectWord={(r) => this.loadResult(r)} onPlayAudio={(url) => this.playAudio(url)} />)}
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

                                <Route exact path="/media/youtube/:id/:startTime">
                                    {this.loginProtect(<MediaYouTubePlayer />)}
                                </Route>
                                <Route exact path="/media/youtube/:id">
                                    {this.loginProtect(<MediaYouTubePlayer />)}
                                </Route>
                                <Route exact path="/media/youtube">
                                    {this.loginProtect(<MediaYouTubePlayer />)}
                                </Route>
                                <Route path="/media/plex">
                                    {this.loginProtect(<MediaPlexPlayer />)}
                                </Route>
                                <Route path="/media/reader/:id?">
                                    {this.loginProtect(<MediaReader />)}
                                </Route>

                                <Route exact path="/articles">
                                    <BlogPosts />
                                </Route>
                                <Route exact path="/article/edit/:id">
                                    {this.loginProtect(<EditBlogPost />)}
                                </Route>
                                <Route ecact path="/article/:id">
                                    <BlogPost />
                                </Route>

                                <Route path="/admin/users">
                                    {this.loginProtect(<AdminUsers />)}
                                </Route>
                                <Route path="/admin/feedback">
                                    {this.loginProtect(<AdminFeedback />)}
                                </Route>

                                <Route path="/auth/resetPassword/:userID/:key">
                                    <ResetPassword show backdrop='static' />
                                </Route>

                                <Route path="/tests/pitchAccent/minimalPairs">
                                    {this.loginProtect(<TestsPitchAccentMinimalPairs />)}
                                </Route>
                                <Route path="/tests/pitchAccent/names">
                                    {this.loginProtect(<TestsPitchAccentNames />)}
                                </Route>
                                <Route path="/tests/pitchAccent/counters">
                                    {this.loginProtect(<TestsPitchAccentCounters />)}
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
                        <ContextMenu {...this.state.showContextMenu} onHide={() => this.setState({ showContextMenu: {} })} />
                    </Router>
                </ColorSchemeContext.Provider>
            </UserContext.Provider>
        );
    }
}

ReactDOM.render(<App />, document.getElementById('app'));
