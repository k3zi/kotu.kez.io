import React from 'react';
import { withRouter } from 'react-router';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import ButtonGroup from 'react-bootstrap/ButtonGroup';
import Col from 'react-bootstrap/Col';
import Dropdown from 'react-bootstrap/Dropdown';
import Form from 'react-bootstrap/Form';
import ListGroup from 'react-bootstrap/ListGroup';
import Pagination from 'react-bootstrap-4-pagination';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';
import ToggleButton from 'react-bootstrap/ToggleButton';

class Search extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            query: '',
            isLoading: false,
            option: null,
            options: [
                {
                    endpoint: '/api/dictionary/search',
                    name: 'Words',
                    value: 'words'
                },
                {
                    endpoint: '/api/media/youtube/subtitles/search',
                    name: 'YouTube',
                    value: 'youtube'
                },
                {
                    endpoint: '/api/media/anki/subtitles/search',
                    name: 'Other',
                    value: 'other'
                }
            ],
            results: [],
            metadata: {
                page: 1,
                per: 15,
                total: 0
            }
        };
    }

    componentDidMount() {
        if (this.props.match.params.query && this.props.match.params.query.length > 0) {
            this.search(this.props.match.params.query, 1);
        }
    }

    componentDidUpdate(prevProps) {
        if (this.props.match.params.query != prevProps.match.params.query && this.props.match.params.query && this.props.match.params.query.length > 0) {
            this.search(this.props.match.params.query, 1);
        }
    }

    loadPage(page) {
        this.search(this.state.query, page);
    }

    loadOption(option) {
        this.search(this.state.query, 1, option);
    }

    async search(query, page, newOption) {
        const option = newOption || this.state.option || this.state.options[0];
        const metadata = this.state.metadata;
        metadata.page = page;
        this.setState({ query, results: [], isLoading: true, option });
        if (query.length === 0) return;
        const response = await fetch(`${option.endpoint}?page=${page}&per=${this.state.metadata.per}&q=${encodeURIComponent(query)}`);
        if (response.ok) {
            const result = await response.json();

            this.setState({
                results: result.items,
                metadata: result.metadata,
                isLoading: false
            });
        }
    }

    render() {
        return (
            <div>
                <h2>Search</h2>
                <Form.Control autoComplete='off' className='text-center' type="text" onChange={(e) => this.search(e.target.value, 1)} placeholder="Search" value={this.state.query} />
                <ButtonGroup className='my-3 d-flex' toggle>
                    {this.state.options.map((option, i) => (
                        <ToggleButton
                            id={option.value}
                            key={i}
                            type="radio"
                            variant="secondary"
                            name="option"
                            value={option.value}
                            checked={this.state.option && this.state.option.value === option.value}
                            onChange={() => this.loadOption(option)}>
                            {option.name}
                        </ToggleButton>
                    ))}
                </ButtonGroup>
                <hr/>
                {this.state.option && this.state.option.value === 'words' && <ListGroup>
                    {this.state.results.map((r, i) => {
                      return <ListGroup.Item action active={false} className='d-flex align-items-center text-break text-wrap' onClick={() => this.props.onSelectWord(r)} style={{ 'white-space': 'normal' }} eventKey={i} key={i}>
                          <img className='me-2' height='20px' src={`/api/dictionary/icon/${r.dictionary.id}`} />
                          {r.headline}
                      </ListGroup.Item>;
                  })}
                </ListGroup>}

                {this.state.option && this.state.option.value === 'youtube' && <ListGroup>
                    {this.state.results.map((s, i) => {
                        return <LinkContainer key={i} to={`/media/youtube/${s.youtubeVideo.youtubeID}/${s.startTime}`}>
                            <ListGroup.Item action className='d-flex align-items-center text-break text-wrap' as="button" style={{ 'white-space': 'normal' }} eventKey={i} >
                                <img className='me-2' height='40px' src={s.youtubeVideo.thumbnailURL} />
                                {s.text}
                            </ListGroup.Item>
                        </LinkContainer>;
                    })}
                </ListGroup>}

                {this.state.option && this.state.option.value === 'other' && <ListGroup>
                    {this.state.results.map((s, i) => {
                        return <ListGroup.Item action key={i} onClick={() => this.props.onPlayAudio(`/api/media/external/audio/${s.externalFile.id}`)} className='d-flex align-items-center text-break text-wrap' as="button" style={{ 'white-space': 'normal' }} eventKey={i} >
                            {s.text}
                        </ListGroup.Item>;
                    })}
                </ListGroup>}
                <Pagination className='mt-3' totalPages={Math.ceil(this.state.metadata.total / this.state.metadata.per)} currentPage={this.state.metadata.page} showMax={7} onClick={(i) => this.loadPage(i)} />
            </div>
        );
    }
}

export default withRouter(Search);
