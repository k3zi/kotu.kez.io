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
            isLoading: true,
            isFocused: false,
            inList: false,
            selectedResult: null,
            selectedResultHTML: '',
            isSubmitting: false,
            headword: null
        };
    }

    componentDidUpdate(prevProps, prevState) {
        if (prevProps.headwords !== this.props.headwords) {
            this.loadHeadword(this.props.headwords[0]);
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
                        <Modal.Body>
                            {this.state.isLoading && <h1 className="text-center" style={{ height: '60vh' }} ><Spinner animation="border" variant="secondary" /></h1>}
                            {!this.state.isLoading && <iframe className="col-12" style={{ height: '60vh' }} srcDoc={this.state.selectedResultHTML} frameBorder="0"></iframe>}
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
