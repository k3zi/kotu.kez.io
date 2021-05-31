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
import Offcanvas from 'react-bootstrap/Offcanvas';
import Spinner from 'react-bootstrap/Spinner';
import Toast from 'react-bootstrap/Toast';

import Changelog from './Changelog';
import Help from './Help';
import Scratchpad from './Scratchpad';
import Home from './Home';
import Search from './Search';

import FeedbackModal from './FeedbackModal';
import LoginModal from './LoginModal';
import RegisterModal from './RegisterModal';
import SearchResultModal from './SearchResultModal';
import SettingsModal from './SettingsModal';
import ContextMenu from './ContextMenu';
import ComponentContextMenu from './ComponentContextMenu';
import CueContextMenu from './CueContextMenu';

import TranscriptionProjects from './Transcription/Projects';
import TranscriptionProject from './Transcription/Project';

import GamesLobbies from './Games/Lobbies';
import GamesLobby from './Games/Lobby';

import FlashcardDeck from './Flashcard/Deck';
import FlashcardDecks from './Flashcard/Decks';
import FlashcardNotes from './Flashcard/Notes';
import FlashcardNoteTypes from './Flashcard/NoteTypes';
import FlashcardNoteType from './Flashcard/NoteType';
import FlashcardCreateNoteModal from './Flashcard/Modals/CreateNoteModal';
import CreateNoteForm from './Flashcard/Modals/CreateNoteForm';

import ListsWords from './Lists/Words';
import AddSentenceModal from './AddSentenceModal';

import MediaYouTubePlayer from './Media/YouTubePlayer';
import MediaPlexPlayer from './Media/PlexPlayer';
import MediaReader from './Media/Reader';

import TestsPitchAccentMinimalPairs from './Tests/PitchAccent/MinimalPairs';
import TestsPitchAccentNames from './Tests/PitchAccent/Names';
import TestsPitchAccentCounters from './Tests/PitchAccent/Counters';

import TestsSyllabaryMinimalPairs from './Tests/Syllabary/MinimalPairs';

import AdminUsers from './Admin/Users';
import AdminFeedback from './Admin/Feedback';
import AdminSubtitles from './Admin/Subtitles';

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
            showOffCanvasMenu: false,
            showContextMenu: {},
            showComponentContextMenu: {},
            showCueContextMenu: {},

            user: null,
            isReady: false,
            numberOfReviews: 0,
            subtitleIndex: undefined,
            willAutoplay: false,

            query: '',
            results: [],
            subtitles: [],
            headwords: [],
            hasDictionaries: true,
            searchNavSelectedOption: 'Words'
        };
        this.abortController = new AbortController();
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
            const match = window.matchMedia('(prefers-color-scheme: dark)');
            if (!match.addEventListener) {
                return;
            }

            match.addEventListener('change', e => {
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

        const self = this;

        document.addEventListener('ankiChange', function (e) {
            self.loadNumberOfReviews();
        });

        Helpers.addLiveEventListeners('cue', 'click', (e, target) => {
            const url = target.dataset.url;
            const subtitleIndex = target.dataset.subtitleIndex;
            this.setState({ subtitleIndex });
            this.playAudio(url, typeof subtitleIndex !== 'undefined' ? `[data-subtitle-index='${subtitleIndex}']` : '');
        });

        Helpers.addLiveEventListeners('cue', 'contextmenu', (e, target) => {
            e.preventDefault();
            const contextMenu = {
                y: e.clientY,
                x: e.clientX,
                selection: window.getSelection().toString(),
                target
            };
            this.setState({ showCueContextMenu: contextMenu });
        });

        Helpers.addLiveEventListeners('.plaintext[contenteditable]', 'paste', (e) => {
            e.preventDefault();
            if (e.clipboardData && e.clipboardData.getData) {
                const text = e.clipboardData.getData('text/plain');
                document.execCommand('insertText', false, text);
            } else if (window.clipboardData && window.clipboardData.getData) {
                const text = window.clipboardData.getData('Text');
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

        Helpers.addLiveEventListeners('component', 'contextmenu', (e, target) => {
            if (!this.state.user.settings.wordStatus.isEnabled) {
                return;
            }
            e.preventDefault();
            const contextMenu = {
                y: e.clientY,
                x: e.clientX,
                selection: window.getSelection().toString(),
                target
            };
            this.setState({ showComponentContextMenu: contextMenu });
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
        if (response.ok) {
            const user = await response.json();
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

            if (user.settings.wordStatus.isEnabled) {
                document.body.classList.add('word-status-enabled');
            } else {
                document.body.classList.remove('word-status-enabled');
            }
            this.setState({ user });
            this.updateColorScheme(user);
        } else {
            this.setState({ user: null });
        }
        this.setState({ isReady: true });
    }

    async loadNumberOfReviews() {
        const response = await fetch('/api/flashcard/numberOfReviews');
        const numberOfReviews = response.ok ? (parseInt(await response.text()) || 0) : 0;
        this.setState({ numberOfReviews });
    }

    update() {
        this.loadNumberOfReviews();
        this.loadUser();
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
        this.abortController.abort();
        this.abortController = new AbortController();
        this.setState({ query, results: [], isLoading: true });
        if (query.length === 0) return;
        const response = await fetch(`/api/dictionary/search?q=${encodeURIComponent(query)}`, { signal: this.abortController.signal });
        if (response.ok) {
            const results = (await response.json()).items;
            if (results.length === 0) {
                const response1 = await fetch('/api/dictionary/all');
                if (response1.ok) {
                    const dictionaries = await response1.json();
                    this.setState({ hasDictionaries: dictionaries.length > 0 });
                }
            }
            this.setState({ results });
        }

        const response2 = await fetch(`/api/media/youtube/subtitles/search?q=${encodeURIComponent(query)}`, { signal: this.abortController.signal });
        const response3 = await fetch(`/api/media/anki/subtitles/search?q=${encodeURIComponent(query)}`, { signal: this.abortController.signal });
        if (response2.ok && response3.ok) {
            const youTubeSubtitles = (await response2.json()).items;
            const ankiSubtites = (await response3.json()).items;
            const subtitles = _.sortBy([...youTubeSubtitles, ...ankiSubtites], 'id');

            this.setState({ subtitles });
        }
    }

    async searchExact(query) {
        if (query.length === 0) return;
        const response = await fetch(`/api/dictionary/exact?q=${encodeURIComponent(query)}&per=100`);
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

    stopAudio() {
        if (this.state.audio) {
            if (this.state.audio.onended) {
                this.state.audio.onended(null);
                this.state.audio.onended = undefined;
            }
            this.state.audio.pause();
            this.setState({ audio: null });
        }
    }

    playAudio(url, selector, isBasic) {
        this.stopAudio();

        let audio = this.audio;
        if (!audio) {
            audio = new Audio(url);
            this.audio = audio;
        } else {
            audio.src = url;
        }
        audio.play();
        if (isBasic) {
            return;
        }
        this.setState({ audio });
        if (selector && selector.length > 0) {
            document.querySelectorAll(selector).forEach(element => {
                element.classList.add('active');
            });
            audio.onended = (e) => {
                const wasNaturalStop = !!e;
                document.querySelectorAll(selector).forEach(element => {
                    element.classList.remove('active');
                });
                if (wasNaturalStop && this.state.user.settings.reader.autoplay) {
                    const subtitleIndex = this.state.subtitleIndex;
                    if (this.state.user.settings.reader.autoplayDelay < 0.5) {
                        this.state.willAutoplay = true;
                        this.state.audio = null;
                        this.playNextSubtitle();
                    } else {
                        this.setState({ willAutoplay: true, audio: null });
                        setTimeout(() => {
                            if (subtitleIndex !== this.state.subtitleIndex) {
                                return;
                            }
                            this.playNextSubtitle();
                        }, this.state.user.settings.reader.autoplayDelay * 1000);
                    }
                }
            };
        } else {
            audio.onended = (e) => {
                const wasNaturalStop = !!e;
                if (wasNaturalStop) {
                    this.setState({ audio: null });
                }
            };
        }
    }

    playNextSubtitle() {
        if (typeof this.state.subtitleIndex === 'undefined') return;
        const lastSubtitleIndex = parseInt(this.state.subtitleIndex);
        if (typeof lastSubtitleIndex === 'undefined' || lastSubtitleIndex === null) return;
        if (!this.state.willAutoplay) {
            this.setState({ subtitleIndex: undefined });
            return;
        }
        this.setState({ willAutoplay: false });
        const subtitleIndex = lastSubtitleIndex + 1;
        const nextCue = document.querySelector(`cue[data-subtitle-index='${subtitleIndex}']`);
        if (!nextCue) {
            this.setState({ subtitleIndex: undefined });
            return;
        }
        if (this.state.user.settings.reader.autoplayScroll) {
            nextCue.scrollIntoView({ behavior: 'smooth' });
        }
        const url = nextCue.dataset.url;
        this.setState({ subtitleIndex });
        this.playAudio(url, typeof subtitleIndex !== 'undefined' ? `[data-subtitle-index='${subtitleIndex}']` : '');
    }

    stopSubtitleAutoplay() {
        this.setState({ subtitleIndex: undefined, willAutoplay: false });
    }

    isAdminVisible() {
        return this.state.user.permissions.includes('admin') || this.state.user.permissions.includes('subtitles');
    }

    renderMenu() {
        return (<>
            <div className="col-12 d-block d-md-none"></div>
            <div className="navbar-expand align-items-center order-0 d-none d-md-flex">
                <LinkContainer to="/" className='d-none d-md-block'>
                    <Navbar.Brand>コツ</Navbar.Brand>
                </LinkContainer>
                {this.state.user && <Nav className="mr-auto" activeKey={window.location.pathname}>
                    {this.isAdminVisible() && <NavDropdown title='Admin'>
                        {this.renderAdminLinks()}
                    </NavDropdown>}

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

                    <LinkContainer exact to="/articles">
                        <Nav.Link active={false}>Articles</Nav.Link>
                    </LinkContainer>

                    <LinkContainer exact to="/games">
                        <Nav.Link active={false}>Games</Nav.Link>
                    </LinkContainer>

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

                        <NavDropdown.Header>Syllabary</NavDropdown.Header>
                        <LinkContainer to="/tests/syllabary/minimalPairs">
                            <NavDropdown.Item active={false}>Minimal Pairs (Perception)</NavDropdown.Item>
                        </LinkContainer>
                    </NavDropdown>

                    <LinkContainer exact to="/transcription">
                        <Nav.Link active={false}>Transcribe</Nav.Link>
                    </LinkContainer>
                </Nav>}
            </div>
            {this.renderSearch('main')}
            <div className="col-12 d-block d-md-none order-2 order-xl-4"></div>
            {!this.state.user && <Nav className="order-2 order-xl-4 d-none d-md-flex">
                <LinkContainer exact to="/articles">
                    <Nav.Link active={false}>Articles</Nav.Link>
                </LinkContainer>
                <Nav.Link href="#" onClick={() => this.toggleLoginModal(true)}>Login</Nav.Link>
                <Nav.Link href="#" onClick={() => this.toggleRegisterModal(true)}>Register</Nav.Link>
            </Nav>}

            {this.state.user && <Nav className="order-1 order-xl-3 d-none d-md-block">
                <Nav.Link className='fs-5 d-inline-block' variant='dark' onClick={() => this.toggleCreateNoteModal(true)}><i className="bi bi-card-text"></i></Nav.Link>
                <NavDropdown className='dropdown-menu-end d-inline-block' title={<i className="bi bi-person-circle"></i>}>
                    <NavDropdown.Item disabled active={false}>Logged in as: <strong>{this.state.user.username}</strong></NavDropdown.Item>
                    <NavDropdown.Divider />
                    <LinkContainer to="/scratchpad">
                        <NavDropdown.Item active={false}>Scratchpad</NavDropdown.Item>
                    </LinkContainer>
                    <NavDropdown.Item active={false} onClick={() => this.toggleShowSettingsModal(true)}>Settings</NavDropdown.Item>
                    <NavDropdown.Divider />
                    <NavDropdown.Item active={false} onClick={() => this.logout()}>Logout</NavDropdown.Item>
                </NavDropdown>
            </Nav>}
        </>);
    }

    renderCollapseMenu() {
        return (<>
            <div className="col-12 d-block d-md-none"></div>
            <div className='collapse col-12 d-md-none' id="dropdownNav">
                <Nav className="mr-auto flex-row flex-wrap d-md-none justify-content-center" activeKey={window.location.pathname}>
                    {!this.state.user && <>
                        <LinkContainer exact to="/articles">
                            <Nav.Link className='col-6 justify-content-center' active={false}>Articles</Nav.Link>
                        </LinkContainer>
                        <div className="col-12"></div>
                        <Nav.Link className='col-6 justify-content-center' href="#" onClick={() => this.toggleLoginModal(true)}>Login</Nav.Link>
                        <Nav.Link className='col-6 justify-content-center' href="#" onClick={() => this.toggleRegisterModal(true)}>Register</Nav.Link>
                    </>}

                    {this.state.user && <>
                        {this.isAdminVisible() && <NavDropdown title='Admin'>
                            {this.renderAdminLinks()}
                        </NavDropdown>}

                        <NavDropdown className='col-6 justify-content-center' title={<>Anki{this.state.numberOfReviews > 0 && <Badge className="ms-2 bg-secondary">{this.state.numberOfReviews}</Badge>}</>}>
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

                        <LinkContainer exact to="/articles">
                            <Nav.Link active={false}>Articles</Nav.Link>
                        </LinkContainer>

                        <LinkContainer exact to="/games">
                            <Nav.Link active={false}>Games</Nav.Link>
                        </LinkContainer>

                        <NavDropdown drop='down' title='Lists'>
                            <LinkContainer to="/lists/words">
                                <NavDropdown.Item active={false}>Words</NavDropdown.Item>
                            </LinkContainer>
                        </NavDropdown>

                        <NavDropdown drop='down' title='Media'>
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

                        <NavDropdown drop='down' title='Tests'>
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

                            <NavDropdown.Header>Syllabary</NavDropdown.Header>
                            <LinkContainer to="/tests/syllabary/minimalPairs">
                                <NavDropdown.Item active={false}>Minimal Pairs (Perception)</NavDropdown.Item>
                            </LinkContainer>
                        </NavDropdown>

                        <LinkContainer exact to="/transcription">
                            <Nav.Link className='col-6 justify-content-center' active={false}>Transcribe</Nav.Link>
                        </LinkContainer>

                        <NavDropdown className='dropdown-menu-end' title={<i className="bi bi-person-circle"></i>}>
                            <NavDropdown.Item disabled active={false}>Logged in as: <strong>{this.state.user.username}</strong></NavDropdown.Item>
                            <NavDropdown.Divider />
                            <LinkContainer to="/scratchpad">
                                <NavDropdown.Item active={false}>Scratchpad</NavDropdown.Item>
                            </LinkContainer>
                            <NavDropdown.Item active={false} onClick={() => this.toggleShowSettingsModal(true)}>Settings</NavDropdown.Item>
                            <NavDropdown.Divider />
                            <NavDropdown.Item active={false} onClick={() => this.logout()}>Logout</NavDropdown.Item>
                        </NavDropdown>
                    </>}
                </Nav>
            </div>
            {this.renderSearch('collapse')}
        </>);
    }

    renderAdminLinks() {
        return (<>
            {this.state.user.permissions.includes('admin') && <>
                <LinkContainer to="/admin/users">
                    <NavDropdown.Item active={false}>Users</NavDropdown.Item>
                </LinkContainer>
                <LinkContainer to="/admin/feedback">
                    <NavDropdown.Item active={false}>Feedback</NavDropdown.Item>
                </LinkContainer>
            </>}
            {(this.state.user.permissions.includes('admin') || this.state.user.permissions.includes('subtitles')) && <>
                <LinkContainer to="/admin/subtitles">
                    <NavDropdown.Item active={false}>Subtitles</NavDropdown.Item>
                </LinkContainer>
            </>}
        </>);
    }

    renderSearch(place) {
        return (this.state.user && <Form as="div" className={`mr-auto col-12 mt-1 mt-xl-0 col-xl-4 order-3 order-xl-1 ${place === 'main' ? 'd-none d-md-inline' : 'd-md-none'}`}>
            <Dropdown>
                <InputGroup className="mr-md-2">
                    <div className='position-relative flex-fill'>
                        <Form.Control className="text-center" type="text" placeholder="Search" onChange={(e) => this.search(e.target.value)} value={this.state.query} onFocus={() => this.setState({ isFocused: true })} />
                        {this.state.query.length > 0 && <span onClick={() => this.search('')} className='position-absolute text-muted' style={{ top: '-2px', right: '4px', 'font-size': '1.75rem', cursor: 'pointer' }}><i className="bi bi-x"></i></span>}
                    </div>
                    <LinkContainer onClick={() => this.setState({ isFocused: false })} to={`/search/${encodeURIComponent(this.state.query)}`}>
                        <Button variant="outline-secondary" disabled={this.state.query.length === 0}>
                            <i className="bi bi-search"></i>
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
        </Form>);
    }

    render() {
        return (
            <UserContext.Provider value={this.state.user}>
                <ColorSchemeContext.Provider value={this.state.colorScheme}>
                    <Router>
                        <Navbar bg="dark" variant="dark" className="justify-content-between px-xl-5 px-2">
                            <LinkContainer to="/" className='d-block d-md-none'>
                                <Navbar.Brand>コツ</Navbar.Brand>
                            </LinkContainer>
                            <div className='d-block d-md-none'>
                                {this.state.user && <Button className='fs-5' variant='dark' onClick={() => this.toggleCreateNoteModal(true)}><i className="bi bi-card-text"></i></Button>}
                                <Button data-bs-toggle="collapse" data-bs-target="#dropdownNav" variant='dark' className='btn btn-dark fs-1 d-inline-flex justify-content-center align-items-center p-1'><i class="bi bi-list"></i></Button>
                            </div>
                            {this.renderMenu()}
                            {this.renderCollapseMenu()}
                        </Navbar>

                        <div className='p-4' style={{ position: 'fixed', bottom: 0, right: 0, zIndex: 1050 }}>
                            <Toast show={!!this.state.audio || this.state.willAutoplay}>
                                <Toast.Header closeButton={false}>
                                    <i className="bi bi-play-circle-fill me-2"></i>
                                    <strong className="me-auto">{this.state.willAutoplay ? 'Autoplay' : 'Playing'}</strong>
                                    {this.state.willAutoplay && <small>just now</small>}
                                </Toast.Header>
                                <Toast.Body>
                                    {this.state.willAutoplay && <span className='fs-6'>Will autoplay next sentence...</span>}
                                    <Button className='d-block col-12 mt-2' variant='danger' onClick={() => this.state.willAutoplay ? this.stopSubtitleAutoplay() : this.stopAudio()}>Stop</Button>
                                </Toast.Body>
                            </Toast>
                        </div>

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
                                <Route path="/scratchpad">
                                    <Scratchpad />
                                </Route>
                                <Route exact path="/search/:query/:optionValue/:page/:per">
                                    {this.loginProtect(<Search onSelectWord={(r) => this.loadResult(r)} onPlayAudio={(url) => this.playAudio(url)} />)}
                                </Route>
                                <Route exact path="/search/:optionValue/:page/:per">
                                    {this.loginProtect(<Search onSelectWord={(r) => this.loadResult(r)} onPlayAudio={(url) => this.playAudio(url)} />)}
                                </Route>
                                <Route exact path="/search/:query">
                                    {this.loginProtect(<Search onSelectWord={(r) => this.loadResult(r)} onPlayAudio={(url) => this.playAudio(url)} />)}
                                </Route>
                                <Route exact path="/search">
                                    {this.loginProtect(<Search onSelectWord={(r) => this.loadResult(r)} onPlayAudio={(url) => this.playAudio(url)} />)}
                                </Route>

                                <Route exact path="/transcription">
                                    {this.loginProtect(<TranscriptionProjects />)}
                                </Route>
                                <Route path="/transcription/:id">
                                    <TranscriptionProject />
                                </Route>

                                <Route exact path="/games">
                                    {this.loginProtect(<GamesLobbies />)}
                                </Route>
                                <Route exact path="/games/lobby/:lobbyID/:connectionID">
                                    {this.loginProtect(<GamesLobby onPlayAudio={(url) => this.playAudio(url)} />)}
                                </Route>

                                <Route exact path="/flashcard/decks">
                                    {this.loginProtect(<FlashcardDecks />)}
                                </Route>
                                <Route exact path="/flashcard/decks/shuffle">
                                    {this.loginProtect(<FlashcardDeck />)}
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
                                <Route exact path="/article/:id">
                                    <BlogPost />
                                </Route>

                                <Route path="/admin/users">
                                    {this.loginProtect(<AdminUsers />)}
                                </Route>
                                <Route path="/admin/feedback">
                                    {this.loginProtect(<AdminFeedback />)}
                                </Route>
                                <Route path="/admin/subtitles">
                                    {this.loginProtect(<AdminSubtitles />)}
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

                                <Route path="/tests/syllabary/minimalPairs">
                                    {this.loginProtect(<TestsSyllabaryMinimalPairs />)}
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
                                <a className='text-white' href='https://github.com/k3zi/kotu.kez.io' target='_blank' rel="noreferrer">Github</a>
                            </p>
                        </footer>

                        <FeedbackModal show={this.state.showFeedbackModal} onHide={() => this.toggleFeedbackModal(false)} />
                        <LoginModal show={this.state.showLoginModal} onHide={() => this.toggleLoginModal(false)} />
                        <RegisterModal show={this.state.showRegisterModal} onHide={() => this.toggleRegisterModal(false)} />
                        <FlashcardCreateNoteModal show={(this.state.user && !this.state.user.settings.ui.prefersCreateNoteOffcanvas) && this.state.showCreateNoteModal} onHide={() => this.toggleCreateNoteModal(false)} onSuccess={() => this.toggleCreateNoteModal(false)} />
                        <AddSentenceModal show={this.state.showAddSentenceModal} onHide={() => this.toggleAddSentenceModal(false)} onSuccess={() => this.toggleAddSentenceModal(false)} />
                        <SearchResultModal headwords={this.state.headwords} show={this.state.headwords.length > 0} onHide={() => this.setState({ headwords: [], isFocused: false })} />
                        <SettingsModal user={this.state.user} show={this.state.showSettingsModal} onHide={() => this.toggleShowSettingsModal(false)} onSave={() => this.loadUser()} />
                        <ContextMenu {...this.state.showContextMenu} onHide={() => this.setState({ showContextMenu: {} })} />
                        <ComponentContextMenu {...this.state.showComponentContextMenu} onHide={() => this.setState({ showComponentContextMenu: {} })} />
                        <CueContextMenu {...this.state.showCueContextMenu} onHide={() => this.setState({ showCueContextMenu: {} })} />

                        <Offcanvas scroll={true} enforceFocus={false} backdrop='static' show={(this.state.user && this.state.user.settings.ui.prefersCreateNoteOffcanvas) && this.state.showCreateNoteModal} onHide={() => this.toggleCreateNoteModal(false)}>
                            <Offcanvas.Header closeButton>
                                <Offcanvas.Title>Create Note</Offcanvas.Title>
                            </Offcanvas.Header>
                            <Offcanvas.Body>
                                <CreateNoteForm {...this.props} onSuccess={() => this.toggleCreateNoteModal(false)} />
                            </Offcanvas.Body>
                        </Offcanvas>
                    </Router>
                </ColorSchemeContext.Provider>
            </UserContext.Provider>
        );
    }
}

ReactDOM.render(<App />, document.getElementById('app'));
