import React, { useContext } from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import ListGroup from 'react-bootstrap/ListGroup';
import Modal from 'react-bootstrap/Modal';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
import Tab from 'react-bootstrap/Tab';
import YouTube from 'react-youtube';

import ColorSchemeContext from './Context/ColorScheme';
import UserContext from './Context/User';

class SearchResultModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isLoading: false,
            isFocused: false,
            inList: false,
            selectedResult: null,
            selectedResultHTML: '',
            isSubmitting: false,
            headword: null,
            frameHeight: '0px',
            frameWidth: '0px'
        };

        this.frameRef = React.createRef();
        this.adjustContentLinks = this.adjustContentLinks.bind(this);
        this.adjustFrameHeight = this.adjustFrameHeight.bind(this);
    }

    componentDidMount() {
        window.addEventListener('resize', () => {
            this.adjustFrameHeight();
        });
    }

    componentDidUpdate(prevProps, prevState) {
        if (prevProps.headwords !== this.props.headwords) {
            this.loadHeadword(this.props.headwords[0]);
        }

        this.adjustFrameHeight();
        this.adjustContentLinks();

        const frame = this.frameRef.current;
        if (frame && this.frame != frame) {
            this.frame = frame;
            frame.addEventListener('load', this.adjustContentLinks);
            frame.addEventListener('load', this.adjustFrameHeight);
        }
    }

    adjustContentLinks() {
        const frame = this.frameRef.current;
        if (!frame) return;
        const anchors = frame.contentWindow.document.getElementsByTagName('a');

        for (let anchor of anchors) {
            var url = new URL(anchor.href);
            if (!url) continue;
            url.searchParams.set('forceHorizontalText', this.context.settings.ui.prefersHorizontalText);
            url.searchParams.set('forceDarkCSS', this.props.colorScheme === 'dark');
            anchor.href = url.href;
        }
    }

    adjustFrameHeight() {
        const frame = this.frameRef.current;
        if (!frame || !frame.contentWindow.document.body) return;
        const writingMode = frame.contentWindow.getComputedStyle(frame.contentWindow.document.body)['writing-mode'];
        const frameHeight = writingMode.includes('vertical') ? '60vh' : (frame.contentWindow.document.documentElement.offsetHeight + 'px');
        const frameWidth = writingMode.includes('vertical') ? (frame.contentWindow.document.documentElement.offsetWidth + 'px') : '100%';
        if (frameHeight != this.state.frameHeight || frameWidth != this.state.frameWidth) {
            this.setState({ frameHeight, frameWidth });
        }
    }

    async loadHeadword(headword) {
        this.setState({ headword });
        if (!headword) {
            return;
        }

        this.setState({ isLoading: true });
        let response;
        if (headword.entry) {
            response = await fetch(`/api/dictionary/entry/${headword.entry.id}?forceHorizontalText=${this.context.settings.ui.prefersHorizontalText ? 'true' : 'false'}&forceDarkCSS=${this.props.colorScheme == 'dark' ? 'true' : 'false'}`);
        } else {
            response = await fetch(`/api/dictionary/entry/${headword.dictionary.id}/${headword.entryIndex}?forceHorizontalText=${this.context.settings.ui.prefersHorizontalText ? 'true' : 'false'}&forceDarkCSS=${this.props.colorScheme == 'dark' ? 'true' : 'false'}`);
        }
        const result = await response.text();
        this.setState({ selectedResultHTML: result, isLoading: false, headword: headword });

        this.checkList();
    }

    async checkList() {
        const response = await fetch(`/api/lists/word/first?q=${encodeURIComponent(this.state.headword.headline)}&isLookup=1`);
        this.setState({ inList: response.ok });
    }

    async addToList() {
        this.setState({ isSubmitting: true });

        const data = {
            value: this.state.headword.headline
        };
        const response = await fetch(`/api/lists/word`, {
            method: 'POST',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        const result = await response.json();
        const success = !result.error;

        this.setState({
            isSubmitting: false,
            inList: response.ok
        });
    }

    render() {
        return (
            <Modal {...this.props} size="lg" centered>
                <Row>
                    {this.props.headwords.length > 1 && <Col sm={4}>
                        <ListGroup variant='flush'>
                            {this.props.headwords.map((headword, i) => (
                                <ListGroup.Item className='d-flex align-items-center' key={i} action onClick={() => this.loadHeadword(headword)}>
                                    <img className='me-2' height='20px' src={`/api/dictionary/icon/${headword.dictionary.id}`} />
                                    {' '}
                                    {headword.headline}
                                </ListGroup.Item>
                            ))}
                        </ListGroup>
                    </Col>}
                    <Col sm={this.props.headwords.length === 1 ? 12 : 8}>
                        <Modal.Header closeButton>
                            <Modal.Title>{this.state.headword && this.state.headword.headline}</Modal.Title>
                            <Button onClick={() => this.addToList()} className='ms-2' variant='primary' disabled={this.state.inList}>{this.state.inList ? 'Added' : 'Add to List'}</Button>
                        </Modal.Header>
                        <Modal.Body className='d-flex justify-content-center align-items-center overflow-auto'>
                            {this.state.isLoading && <h1 className="text-center" style={{ height: '60vh' }} ><Spinner animation="border" variant="secondary" /></h1>}
                            {!this.state.isLoading && <iframe ref={this.frameRef} className="col-12" style={{ height: this.state.frameHeight, width: this.state.frameWidth }} srcDoc={this.state.selectedResultHTML} frameBorder="0"></iframe>}
                        </Modal.Body>
                    </Col>
                </Row>
            </Modal>
        );
    }
}

SearchResultModal.contextType = UserContext;
export default props => ( <ColorSchemeContext.Consumer>
    {(colorScheme) => {
       return <SearchResultModal {...props} colorScheme={colorScheme} />
    }}
  </ColorSchemeContext.Consumer>
)
