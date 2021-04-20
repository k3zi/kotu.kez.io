import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Carousel from 'react-bootstrap/Carousel';
import Col from 'react-bootstrap/Col';
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
import Table from 'react-bootstrap/Table';

import ContentEditable from './../Common/ContentEditable';
import DeleteWordModal from './Modals/DeleteWordModal';

class Words extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showDeleteModal: null,
            showExamples: null,
            userExamples: null,
            otherExamples: null,
            words: []
        };
    }

    componentDidMount() {
        this.load();
    }

    async load() {
        const response = await fetch('/api/lists/words');
        if (response.ok) {
            const words = await response.json();
            this.setState({ words });
        }
    }

    async showDeleteModal(word) {
        this.setState({
            showDeleteModal: word
        });
        await this.load();
    }

    async updateNote(word, note) {
        word.note = note;
        await fetch(`/api/lists/word/${word.id}`, {
            method: 'PUT',
            body: JSON.stringify(word),
            headers: {
                'Content-Type': 'application/json'
            }
        });
    }

    async showExamples(word) {
        this.setState({ showExamples: word, userExamples: null, otherExamples: null });
        if (!word) {
            return;
        }
        const values = word.value.split(/[\s・,、【［］】「」]/g).filter(s => s.length > 0).join('|');
        const encodedValues = encodeURIComponent(values);

        let userExamples = [];
        const response1 = await fetch(`/api/media/reader/sessions/search?q=${encodedValues}`);
        if (response1.ok) {
            userExamples = (await response1.json()).items;
        }

        let otherExamples = [];
        const response2 = await fetch(`/api/media/anki/subtitles/search?q=${encodedValues}`);
        if (response2.ok) {
            otherExamples = (await response2.json()).items;
        }

        this.setState({ userExamples, otherExamples });
    }

    render() {
        return (
            <div>
                <h2>Lists <small className="text-muted">{this.state.words.length} Words(s)</small></h2>
                <hr/>
                <Table striped bordered hover>
                    <thead>
                        <tr>
                            <th className="text-center col-3">Word</th>
                            <th className="text-center col-auto">Note</th>
                            <th className="text-center col-1">Lookup(s)</th>
                            <th className="text-center col-1">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {this.state.words.map((word, i) => {
                            return (<>
                                <tr key={i * 2}>
                                    <td className="align-middle">{word.value}</td>
                                    <td className="align-middle">
                                        <ContentEditable value={word.note} onChange={(e) => this.updateNote(word, e.target.value)} className='form-control h-auto text-break plaintext' />
                                    </td>
                                    <td className="align-middle text-center">{word.lookups}</td>
                                    <td className="align-middle text-center">
                                        <Button className='me-1' variant="primary" onClick={() => this.state.showExamples == word ? this.showExamples(null) : this.showExamples(word)}>例</Button>
                                        <Button variant="danger" onClick={() => this.showDeleteModal(word)}><i className="bi bi-trash"></i></Button>
                                    </td>
                                </tr>
                                {this.state.showExamples == word && <tr key={i * 2 + 1}>
                                    <td colSpan={4} className="align-middle carousel-caption-position-relative">
                                        {!this.state.userExamples && <h1 className="text-center mt-1 mb-3"><Spinner animation="border" variant="secondary" /></h1>}
                                        {this.state.userExamples && this.state.userExamples.length > 0 && <Carousel interval={15000}>
                                            {this.state.userExamples.map(example => {
                                                return <Carousel.Item>
                                                    <Carousel.Caption>
                                                        <figure>
                                                            <blockquote class='blockquote border-0 my-3 mx-5 px-5'>
                                                                <p>{example.text}</p>
                                                            </blockquote>
                                                            <figcaption class='blockquote-footer'>
                                                                {example.session.title || '(Unnamed Session)'}
                                                            </figcaption>
                                                        </figure>
                                                    </Carousel.Caption>
                                                </Carousel.Item>;
                                            })}
                                        </Carousel>}
                                        {this.state.otherExamples && this.state.otherExamples.length > 0 && <Carousel interval={15000}>
                                            {this.state.otherExamples.map(example => {
                                                return <Carousel.Item>
                                                    <Carousel.Caption>
                                                        <figure>
                                                            <blockquote class='blockquote border-0 my-3 mx-5 px-5'>
                                                                <p>{example.text}</p>
                                                            </blockquote>
                                                            <figcaption class='blockquote-footer'>
                                                                {example.video.title || '(Unnamed Source)'}
                                                            </figcaption>
                                                        </figure>
                                                    </Carousel.Caption>
                                                </Carousel.Item>;
                                            })}
                                        </Carousel>}
                                    </td>
                                </tr>}
                            </>);
                        })}
                    </tbody>
                </Table>

                <DeleteWordModal word={this.state.showDeleteModal} show={this.state.showDeleteModal} didDelete={() => this.showDeleteModal(null)} didCancel={() => this.showDeleteModal(null)} onHide={() => this.showDeleteModal(null)} />
            </div>
        );
    }
}

export default Words;
